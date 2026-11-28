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
        screenConfigurationAtPresentation = AuxiliaryWindowFramePolicy.screenConfiguration()
        isApplyingProgrammaticFrame = true
        defer { isApplyingProgrammaticFrame = false }
        let saved = appearance.frame(for: operationKey).flatMap { shouldRestoreFrame($0) ? $0 : nil }
        hasManualHeight = saved?.manualHeight == true
        let width = max(panel.minSize.width, saved.map { CGFloat($0.width) } ?? appearance.panelWidth)
        let height = saved.flatMap { $0.manualHeight == true ? CGFloat($0.height) : nil } ?? Layout.minimumPanelHeight
        panel.setFrame(NSRect(origin: panel.frame.origin, size: NSSize(width: width, height: height)), display: false)
        if let saved, let mainFrame = hostWindowFrame() {
            panel.setFrameOrigin(NSPoint(x: mainFrame.minX + CGFloat(saved.relativeX), y: mainFrame.minY + CGFloat(saved.relativeY)))
        } else {
            centerInMainWindow()
        }
        clampPanelToScreen()
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
            lineCount: lineCount,
            screenConfiguration: screenConfigurationAtPresentation,
            manualHeight: hasManualHeight
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

    // MARK: - Schedule Output Resize
    func scheduleOutputResize() {
        guard !hasManualHeight, outputResizeTask == nil, let panel, panel.isVisible,
              panel.frame.height < maximumAutomaticHeight else { return }
        outputResizeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            outputResizeTask = nil
            resizeToFitOutput()
        }
    }

    // MARK: - Resize to Fit Output
    func resizeToFitOutput() {
        guard !hasManualHeight, let panel, panel.isVisible else { return }
        let oldFrame = panel.frame
        var height = Layout.minimumPanelHeight
        if lineCount > 0, let scrollView, let text = logTextView,
           let manager = text.layoutManager, let container = text.textContainer {
            panel.contentView?.layoutSubtreeIfNeeded()
            manager.ensureLayout(for: container)
            let logHeight = manager.usedRect(for: container).height + Layout.logInset.height * 2
            let chromeHeight = oldFrame.height - scrollView.frame.height
            height = min(maximumAutomaticHeight, max(height, ceil(chromeHeight + logHeight)))
        }
        guard abs(oldFrame.height - height) >= 2 else { return }
        isApplyingProgrammaticFrame = true
        defer { isApplyingProgrammaticFrame = false }
        panel.setFrame(NSRect(x: oldFrame.minX, y: oldFrame.maxY - height, width: oldFrame.width, height: height), display: true)
        clampPanelToScreen()
        logTextView?.scrollToEndOfDocument(nil)
    }

    private var maximumAutomaticHeight: CGFloat {
        let visibleHeight = presentationHostWindow?.screen?.visibleFrame.height ?? NSScreen.main?.visibleFrame.height ?? 720
        return max(Layout.minimumPanelHeight, min(appearance.panelHeight, visibleHeight - 24))
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
    func clampPanelToScreen() {
        guard let panel else { return }
        AuxiliaryWindowFramePolicy.ensureVisible(panel, preferredScreen: presentationHostWindow?.screen)
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
    func shouldRestoreFrame(_ saved: ProgressPanelFrame) -> Bool {
        let values = [saved.relativeX, saved.relativeY, saved.width, saved.height]
        guard values.allSatisfy(\.isFinite) else { return false }
        guard saved.screenConfiguration == AuxiliaryWindowFramePolicy.screenConfiguration() else { return false }
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

}
