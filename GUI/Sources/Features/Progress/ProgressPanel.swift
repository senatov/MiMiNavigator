// ProgressPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 07.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Universal resizable non-modal HUD for long-running ops (archive, file, network).
//   Scrollable log, status line, Cancel→OK btn. Appearance via ProgressPanelAppearance.
//   Panel size persisted in ~/.mimi/progress_appearance.json.

import AppKit

// MARK: - ProgressPanel
@MainActor
final class ProgressPanel: NSObject {
    // MARK: - Singleton
    static let shared = ProgressPanel()

    // MARK: - Layout
    enum Layout {
        static let containerCornerRadius: CGFloat = 12
        static let outerPadding: CGFloat = 14
        static let topInset: CGFloat = 10
        static let iconSize: CGFloat = 22
        static let titleSpacing: CGFloat = 8
        static let statusTopSpacing: CGFloat = 6
        static let progressTopSpacing: CGFloat = 8
        static let progressHeight: CGFloat = 10
        static let logTopSpacing: CGFloat = 8
        static let buttonBottomInset: CGFloat = 10
        static let logCornerRadius: CGFloat = 6
        static let logInset = NSSize(width: 4, height: 4)
        static let logLinePadding: CGFloat = 0
        static let borderWidth: CGFloat = 0.5
        static let buttonMinWidth: CGFloat = 92
        static let buttonHeight: CGFloat = 30
        static let compactLineLimit = 6
        static let compactExtraHeight: CGFloat = 168
        static let compactHeightPadding: CGFloat = 18
        static let minimumPanelHeight: CGFloat = 248
    }

    // MARK: - UI
    var panel: NSPanel?
    var container: NSView?
    var iconView: NSImageView?
    var titleLabel: NSTextField?
    var statusLabel: NSTextField?
    var progressIndicator: NSProgressIndicator?
    var progressHeightConstraint: NSLayoutConstraint?
    var logTextView: NSTextView?
    var scrollView: NSScrollView?
    var actionButton: NSButton?
    var backgroundEffectView: NSVisualEffectView?
    var logBackgroundEffectView: NSVisualEffectView?
    // MARK: - State
    var isCancelled = false
    var isFinished = false
    var autoCloseSuppressedByUser = false
    var autoCloseGeneration = 0
    var lastActionButtonActionTime: TimeInterval = 0
    var lineCount = 0
    var onCancel: (() -> Void)?
    var eventMonitor: Any?
    var operationKey = "default"
    var autoCloseTask: Task<Void, Never>?
    private override init() { super.init() }
    var appearance: ProgressPanelAppearance { .shared }

    // MARK: - Compatibility Helpers
    func reset(title: String, message: String, icon: String = "archivebox.fill") {
        if panel == nil { createPanel() }
        isCancelled = false
        isFinished = false
        autoCloseSuppressedByUser = false
        lineCount = 0
        operationKey = "reset"
        resetContent(icon: icon, title: title, status: message)
    }

    func setCancelHandler(_ handler: (() -> Void)?) {
        onCancel = handler
        actionButton?.isEnabled = true
        if !isFinished {
            actionButton?.title = "Cancel"
            applyActionButtonStyle(.cancel)
        }
    }

    func appendLine(_ line: String) {
        appendLog(line)
    }
    // MARK: - Show
    func show(
        icon: String = "archivebox.fill",
        title: String,
        status: String,
        operationKey: String? = nil,
        cancelHandler: (() -> Void)? = nil
    ) {
        ArchiveInfoPopupController.shared.hide()
        isCancelled = false
        isFinished = false
        autoCloseSuppressedByUser = false
        lineCount = 0
        onCancel = cancelHandler
        cancelAutoCloseTimer()
        self.operationKey = normalizedOperationKey(operationKey ?? title)
        if panel == nil { createPanel() }
        guard let panel else { return }
        resetContent(icon: icon, title: title, status: status)
        restoreFrameForCurrentOperation()
        attachPanelToMainWindow(panel)
        animatePanelIn(panel)
        log.debug("[ProgressPanel] \(#function) title='\(title)'")
    }
    // MARK: - Convenience: extraction
    func show(archiveName: String, destinationPath: String, cancelHandler: (() -> Void)? = nil) {
        show(
            icon: "archivebox.fill",
            title: "📦 \(archiveName)",
            status: "Extracting to \(abbreviatePath(destinationPath))…",
            operationKey: "extract",
            cancelHandler: cancelHandler)
    }
    // MARK: - Convenience: packing
    func showPacking(archiveName: String, destinationPath: String, fileCount: Int, cancelHandler: (() -> Void)? = nil) {
        show(
            icon: "archivebox.fill",
            title: "📦 Packing → \(archiveName)",
            status: "Packing \(fileCount) item(s) to \(abbreviatePath(destinationPath))…",
            operationKey: "pack",
            cancelHandler: cancelHandler)
    }
    // MARK: - Convenience: file operation
    func showFileOp(
        icon: String = "doc.on.doc", title: String, itemCount: Int, destination: String, cancelHandler: (() -> Void)? = nil
    ) {
        show(
            icon: icon,
            title: title,
            status: "\(itemCount) item(s) → \(abbreviatePath(destination))…",
            operationKey: title,
            cancelHandler: cancelHandler)
    }
    // MARK: - Append Log Line
    func appendLog(_ line: String) {
        guard let tv = logTextView else { return }
        lineCount += 1
        let entry = "\(lineCount). \(line)\n"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: appearance.logFont,
            .foregroundColor: appearance.logColor,
        ]
        tv.textStorage?.append(NSAttributedString(string: entry, attributes: attrs))
        tv.scrollToEndOfDocument(nil)
    }

    // MARK: - Append Attributed Log
    func appendAttributedLog(_ content: NSAttributedString) {
        guard let tv = logTextView else { return }
        lineCount += 1
        let prefix = NSAttributedString(
            string: "\(lineCount). ",
            attributes: [.font: appearance.logFont, .foregroundColor: appearance.logColor])
        let entry = NSMutableAttributedString(attributedString: prefix)
        entry.append(content)
        entry.append(NSAttributedString(string: "\n", attributes: [.font: appearance.logFont]))
        tv.textStorage?.append(entry)
        tv.scrollToEndOfDocument(nil)
    }

    // MARK: - Update Status
    func updateStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    func updateProgress(_ fraction: Double?) {
        guard let indicator = progressIndicator else { return }
        setProgressVisible(true)
        if let fraction {
            indicator.stopAnimation(nil)
            indicator.isIndeterminate = false
            indicator.minValue = 0
            indicator.maxValue = 1
            indicator.doubleValue = min(max(fraction, 0), 1)
        } else {
            indicator.isIndeterminate = true
            indicator.startAnimation(nil)
        }
    }

    func hideProgress() {
        progressIndicator?.stopAnimation(nil)
        setProgressVisible(false)
    }

    // MARK: - Update (preferred for live progress)
    func update(text: String) {
        guard panel?.isVisible == true else { return }
        statusLabel?.stringValue = text
    }
    // MARK: - Finish (Cancel → OK)
    func finish(success: Bool, message: String? = nil, autoClose: Bool = true) {
        if let msg = message {
            statusLabel?.stringValue = msg
        } else {
            statusLabel?.stringValue =
                success
                ? "✅ Done — \(lineCount) item(s) processed"
                : "❌ Operation failed"
        }
        actionButton?.title = "OK"
        actionButton?.isEnabled = true
        actionButton?.keyEquivalent = "\r"
        applyActionButtonStyle(.confirm)
        isFinished = true
        if success && progressIndicator?.isHidden == false {
            updateProgress(1)
        } else {
            hideProgress()
        }
        onCancel = nil
        compactForShortOutputIfNeeded()
        if autoClose {
            startAutoCloseTimerIfNeeded()
        }
        log.debug("[ProgressPanel] \(#function) success=\(success) lines=\(lineCount)")
    }

    func finish(success: Bool, details: String?) {
        finish(success: success, message: details, autoClose: true)
    }

    // MARK: - Suspend for User Decision
    func suspendForUserDecision() {
        guard let panel, panel.isVisible else { return }
        if let parent = panel.parent {
            parent.removeChildWindow(panel)
        }
        panel.orderOut(nil)
    }

    // MARK: - Resume after User Decision
    func resumeAfterUserDecision() {
        guard let panel, panel.isVisible == false else { return }
        clampPanelToMainWindow()
        attachPanelToMainWindow(panel)
        animatePanelIn(panel)
    }

    // MARK: - Hide
    func hide() {
        guard let panel, panel.isVisible else { return }
        autoCloseGeneration += 1
        cancelAutoCloseTimer()
        persistFrameForCurrentOperation()
        let parent = panel.parent
        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            },
            completionHandler: {
                Task { @MainActor in
                    parent?.removeChildWindow(panel)
                    panel.orderOut(nil)
                    self.removeEventMonitor()
                }
            })
    }

}
