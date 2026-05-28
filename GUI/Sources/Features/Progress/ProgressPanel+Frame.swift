// ProgressPanel+Frame.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ProgressPanel frame persistence, compact sizing, and auto-close timer.

import AppKit

// MARK: - Frame

extension ProgressPanel {
    // MARK: - Center in Main Window
    func centerInMainWindow() {
        guard let panel else { return }
        if let mainFrame = (NSApp.mainWindow ?? NSApp.keyWindow)?.frame {
            let x = mainFrame.midX - panel.frame.width / 2
            let y = mainFrame.midY - panel.frame.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
    }

    // MARK: - Restore Frame
    func restoreFrameForCurrentOperation() {
        guard let panel else { return }
        applySavedSizeIfNeeded(to: panel)
        if let saved = appearance.frame(for: operationKey),
           shouldRestoreFrame(saved),
           let mainFrame = (NSApp.mainWindow ?? NSApp.keyWindow)?.frame {
            let width = clampedWidth(CGFloat(saved.width), mainFrame: mainFrame)
            let height = clampedHeight(restoredHeight(for: saved), mainFrame: mainFrame)
            let x = mainFrame.minX + CGFloat(saved.relativeX)
            let y = mainFrame.minY + CGFloat(saved.relativeY)
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
            clampPanelToMainWindow()
            return
        }
        clampPanelToMainWindow()
        centerInMainWindow()
    }

    // MARK: - Persist Frame
    func persistFrameForCurrentOperation() {
        guard let panel, let mainFrame = (NSApp.mainWindow ?? NSApp.keyWindow)?.frame else { return }
        let frame = panel.frame
        let stored = ProgressPanelFrame(
            relativeX: Double(frame.minX - mainFrame.minX),
            relativeY: Double(frame.minY - mainFrame.minY),
            width: Double(frame.width),
            height: Double(frame.height),
            lineCount: lineCount
        )
        appearance.updateFrame(stored, for: operationKey)
    }

    // MARK: - Compact
    func compactForShortOutputIfNeeded() {
        guard let panel, lineCount > 0, lineCount <= Layout.compactLineLimit else { return }
        let compactHeight = compactHeight(for: lineCount)
        guard panel.frame.height > compactHeight + Layout.compactHeightPadding else { return }
        let oldFrame = panel.frame
        let newFrame = NSRect(x: oldFrame.midX - oldFrame.width / 2, y: oldFrame.midY - compactHeight / 2, width: oldFrame.width, height: compactHeight)
        panel.setFrame(newFrame, display: true, animate: true)
        clampPanelToMainWindow()
        persistFrameForCurrentOperation()
        log.debug("[ProgressPanel] compacted short output lines=\(lineCount) height=\(Int(compactHeight))")
    }

    // MARK: - Auto Close
    func startAutoCloseTimerIfNeeded(seconds overrideSeconds: Int? = nil) {
        guard isFinished else { return }
        guard !autoCloseSuppressedByUser else {
            log.debug("[ProgressPanel] auto-close skipped: user interacted")
            return
        }
        cancelAutoCloseTimer()
        autoCloseGeneration += 1
        let generation = autoCloseGeneration
        let seconds = overrideSeconds ?? appearance.autoCloseSeconds
        guard seconds > 0 else { return }
        log.debug("[ProgressPanel] auto-close started seconds=\(seconds) generation=\(generation)")
        autoCloseTask = Task { @MainActor in
            for remaining in stride(from: seconds, through: 1, by: -1) {
                guard generation == autoCloseGeneration, !autoCloseSuppressedByUser else { return }
                actionButton?.title = "OK (\(remaining))"
                applyActionButtonStyle(.confirm)
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, generation == autoCloseGeneration, !autoCloseSuppressedByUser else { return }
            }
            guard generation == autoCloseGeneration, !autoCloseSuppressedByUser else { return }
            actionButton?.title = "OK"
            applyActionButtonStyle(.confirm)
            log.debug("[ProgressPanel] auto-close elapsed generation=\(generation)")
            hide()
        }
    }

    // MARK: - Cancel Auto Close
    func cancelAutoCloseTimer() {
        let hadTask = autoCloseTask != nil
        autoCloseGeneration += 1
        autoCloseTask?.cancel()
        autoCloseTask = nil
        if actionButton?.title.hasPrefix("OK (") == true {
            actionButton?.title = "OK"
            applyActionButtonStyle(.confirm)
        }
        if hadTask {
            log.debug("[ProgressPanel] auto-close cancelled")
        }
    }

    // MARK: - Register User Interaction
    func registerUserInteraction(source: String) {
        guard panel?.isVisible == true, autoCloseTask != nil else { return }
        let shouldLog = !autoCloseSuppressedByUser || autoCloseTask != nil
        autoCloseSuppressedByUser = true
        cancelAutoCloseTimer()
        if shouldLog {
            log.debug("[ProgressPanel] user interaction source=\(source)")
        }
    }

    // MARK: - Clamp Panel
    func clampPanelToMainWindow() {
        guard let panel else { return }
        let mainFrame = (NSApp.mainWindow ?? NSApp.keyWindow)?.frame ?? NSScreen.main?.visibleFrame
        let availableWidth = max(ProgressPanelAppearance.defaultMinWidth, (mainFrame?.width ?? 760) - 48)
        let availableHeight = max(ProgressPanelAppearance.defaultMinHeight, (mainFrame?.height ?? 520) - 80)
        let targetWidth = min(panel.frame.width, min(availableWidth, 760))
        let targetHeight = min(panel.frame.height, min(availableHeight, 520))
        let current = panel.frame
        let minX = mainFrame?.minX ?? current.minX
        let minY = mainFrame?.minY ?? current.minY
        let maxX = (mainFrame?.maxX ?? current.maxX) - targetWidth
        let maxY = (mainFrame?.maxY ?? current.maxY) - targetHeight
        let targetX = min(max(current.minX, minX), maxX)
        let targetY = min(max(current.minY, minY), maxY)
        let targetFrame = NSRect(x: targetX, y: targetY, width: targetWidth, height: targetHeight)
        guard targetFrame != current else { return }
        panel.setFrame(targetFrame, display: false)
    }

    // MARK: - Abbreviate Path
    func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Helpers
    func applySavedSizeIfNeeded(to panel: NSPanel) {
        let saved = appearance.frame(for: operationKey)
        let width = saved.map { shouldRestoreFrame($0) ? CGFloat($0.width) : ProgressPanelAppearance.defaultWidth } ?? ProgressPanelAppearance.defaultWidth
        let height = saved.map { shouldRestoreFrame($0) ? restoredHeight(for: $0) : ProgressPanelAppearance.defaultHeight } ?? ProgressPanelAppearance.defaultHeight
        panel.setFrame(NSRect(x: panel.frame.minX, y: panel.frame.minY, width: width, height: height), display: false)
    }

    func shouldRestoreFrame(_ saved: ProgressPanelFrame) -> Bool {
        if saved.relativeX < 12 || saved.relativeY < 12 { return false }
        if saved.width < Double(ProgressPanelAppearance.defaultWidth * 0.85) { return false }
        if saved.height < Double(ProgressPanelAppearance.defaultHeight * 0.85) { return false }
        return true
    }

    func restoredHeight(for saved: ProgressPanelFrame) -> CGFloat {
        if let savedLineCount = saved.lineCount, savedLineCount <= Layout.compactLineLimit {
            return compactHeight(for: savedLineCount)
        }
        if saved.lineCount == nil, saved.height > Double(ProgressPanelAppearance.defaultHeight + 80) {
            return ProgressPanelAppearance.defaultHeight
        }
        return CGFloat(saved.height)
    }

    func compactHeight(for lines: Int) -> CGFloat {
        let fontHeight = ceil(appearance.logFont.ascender - appearance.logFont.descender + appearance.logFont.leading)
        let visibleLines = max(3, min(lines, Layout.compactLineLimit))
        let logHeight = CGFloat(visibleLines) * fontHeight + Layout.logInset.height * 2
        return max(Layout.minimumPanelHeight, Layout.compactExtraHeight + logHeight)
    }

    func normalizedOperationKey(_ rawValue: String) -> String {
        let lowered = rawValue.lowercased()
        if lowered.contains("copy") { return "copy" }
        if lowered.contains("move") { return "move" }
        if lowered.contains("delete") || lowered.contains("delet") || lowered.contains("trash") { return "delete" }
        if lowered.contains("upload") || lowered.contains("⬆") { return "upload" }
        if lowered.contains("download") || lowered.contains("⬇") { return "download" }
        if lowered.contains("pack") { return "pack" }
        if lowered.contains("extract") { return "extract" }
        if lowered.contains("connect") || lowered.contains("disconnect") { return "connection" }
        if lowered.contains("convert") { return "convert" }
        if lowered.contains("find") || lowered.contains("search") { return "search" }
        let allowed = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(allowed).split(separator: "-").joined(separator: "-")
    }

    func clampedWidth(_ width: CGFloat, mainFrame: NSRect) -> CGFloat {
        min(max(width, ProgressPanelAppearance.defaultMinWidth), max(ProgressPanelAppearance.defaultMinWidth, mainFrame.width - 48))
    }

    func clampedHeight(_ height: CGFloat, mainFrame: NSRect) -> CGFloat {
        min(max(height, Layout.minimumPanelHeight), max(Layout.minimumPanelHeight, mainFrame.height - 80))
    }
}
