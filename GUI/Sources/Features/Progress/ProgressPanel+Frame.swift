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
        if let mainFrame = hostWindowFrame() {
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
        isApplyingProgrammaticFrame = true
        defer { isApplyingProgrammaticFrame = false }
        applySavedSizeIfNeeded(to: panel)
        clampPanelToMainWindow()
        centerInMainWindow()
    }

    // MARK: - Persist Frame
    func persistFrameForCurrentOperation() {
        guard let panel, let mainFrame = hostWindowFrame() else { return }
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

    // MARK: - Schedule Frame Persistence
    func scheduleFramePersistence() {
        framePersistenceTask?.cancel()
        framePersistenceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, !isApplyingProgrammaticFrame else { return }
            persistFrameForCurrentOperation()
            framePersistenceTask = nil
        }
    }

    // MARK: - Compact
    func compactForShortOutputIfNeeded() {
        guard let panel, lineCount > 0, lineCount <= Layout.compactLineLimit else { return }
        guard appearance.frame(for: operationKey) == nil else { return }
        let compactHeight = compactHeight(for: lineCount)
        guard panel.frame.height > compactHeight + Layout.compactHeightPadding else { return }
        let oldFrame = panel.frame
        let newFrame = NSRect(x: oldFrame.midX - oldFrame.width / 2, y: oldFrame.midY - compactHeight / 2, width: oldFrame.width, height: compactHeight)
        isApplyingProgrammaticFrame = true
        panel.setFrame(newFrame, display: true)
        clampPanelToMainWindow()
        isApplyingProgrammaticFrame = false
        persistFrameForCurrentOperation()
        log.debug("[ProgressPanel] compacted short output lines=\(lineCount) height=\(Int(compactHeight))")
    }

    // MARK: - Auto Close
    func startAutoCloseTimerIfNeeded(seconds overrideSeconds: Double? = nil) {
        guard isFinished else { return }
        guard appearance.autoCloseEnabled else {
            log.debug("[ProgressPanel] auto-close skipped: preference disabled")
            return
        }
        guard !autoCloseSuppressedByUser else {
            log.debug("[ProgressPanel] auto-close skipped: user interacted")
            return
        }
        cancelAutoCloseTimer()
        autoCloseGeneration += 1
        let generation = autoCloseGeneration
        let seconds = overrideSeconds ?? appearance.autoCloseSeconds
        let tenths = Int((seconds * 10).rounded())
        guard tenths > 0 else { return }
        log.debug("[ProgressPanel] auto-close started seconds=\(seconds) generation=\(generation)")
        autoCloseTask = Task { @MainActor in
            for remainingTenths in stride(from: tenths, through: 1, by: -1) {
                guard generation == autoCloseGeneration, !autoCloseSuppressedByUser else { return }
                actionButton?.title = "OK (\(formatAutoCloseSeconds(remainingTenths)))"
                applyActionButtonStyle(.confirm)
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, generation == autoCloseGeneration, !autoCloseSuppressedByUser else { return }
            }
            guard generation == autoCloseGeneration, !autoCloseSuppressedByUser else { return }
            actionButton?.title = "OK"
            applyActionButtonStyle(.confirm)
            log.debug("[ProgressPanel] auto-close elapsed generation=\(generation)")
            hide()
        }
    }

    // MARK: - Format Auto Close Seconds
    func formatAutoCloseSeconds(_ tenths: Int) -> String {
        String(format: "%.1f", Double(tenths) / 10)
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
        let mainFrame = hostWindowFrame() ?? NSScreen.main?.visibleFrame
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
        let values = [saved.relativeX, saved.relativeY, saved.width, saved.height]
        guard values.allSatisfy(\.isFinite) else { return false }
        if abs(saved.relativeX) < 1, abs(saved.relativeY) < 1 { return false }
        guard saved.width >= Double(ProgressPanelAppearance.defaultMinWidth) else { return false }
        return saved.height >= Double(Layout.minimumPanelHeight)
    }

    func hostWindowFrame() -> NSRect? {
        if let presentationHostWindow, presentationHostWindow.isVisible { return presentationHostWindow.frame }
        if let parent = panel?.parent { return parent.frame }
        if let mainWindow = NSApp.mainWindow, mainWindow !== panel { return mainWindow.frame }
        if let keyWindow = NSApp.keyWindow, keyWindow !== panel, !(keyWindow is NSPanel) { return keyWindow.frame }
        return NSApp.windows.first { $0 !== panel && !($0 is NSPanel) && $0.isVisible }?.frame
    }

    // MARK: - Presentation Host
    func currentPresentationHostWindow() -> NSWindow? {
        if let keyWindow = NSApp.keyWindow, keyWindow !== panel { return keyWindow }
        if let mainWindow = NSApp.mainWindow, mainWindow !== panel { return mainWindow }
        return NSApp.windows.first { $0 !== panel && $0.isVisible }
    }

    func restoredHeight(for saved: ProgressPanelFrame) -> CGFloat {
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
