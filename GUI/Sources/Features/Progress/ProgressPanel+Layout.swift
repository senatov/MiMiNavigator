// ProgressPanel+Layout.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ProgressPanel AppKit view construction and appearance helpers.

import AppKit

// MARK: - Layout

extension ProgressPanel {
    // MARK: - View Factories
    func makeContainerView() -> NSView {
        let view = ProgressInteractionView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.cornerRadius = Layout.containerCornerRadius
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = Layout.borderWidth
        view.onInteraction = { [weak self] in
            Task { @MainActor in
                self?.registerUserInteraction(source: "container")
            }
        }
        return view
    }

    func makeBackgroundEffectView() -> NSVisualEffectView {
        let effectView = ProgressInteractionEffectView()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = Layout.containerCornerRadius
        effectView.layer?.masksToBounds = true
        effectView.onInteraction = { [weak self] in
            Task { @MainActor in
                self?.registerUserInteraction(source: "background")
            }
        }
        return effectView
    }

    func makeLogEffectView() -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .sidebar
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = Layout.logCornerRadius
        effectView.layer?.masksToBounds = true
        return effectView
    }

    // MARK: - Appearance
    func configureContainerAppearance() {
        let a = appearance
        container?.layer?.backgroundColor = a.bgColor.withAlphaComponent(0.92).cgColor
        container?.layer?.borderColor = a.borderColor.cgColor
        backgroundEffectView?.alphaValue = 1
    }

    func configureLogContainerAppearance() {
        let a = appearance
        scrollView?.layer?.cornerRadius = Layout.logCornerRadius
        scrollView?.layer?.borderColor = a.borderColor.cgColor
        scrollView?.layer?.borderWidth = Layout.borderWidth
        logBackgroundEffectView?.alphaValue = 0.72
    }

    // MARK: - Content Reset
    func resetContent(icon: String, title: String, status: String) {
        cancelAutoCloseTimer()
        iconView?.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        titleLabel?.stringValue = title
        statusLabel?.stringValue = status
        progressIndicator?.stopAnimation(nil)
        progressIndicator?.isIndeterminate = false
        progressIndicator?.doubleValue = 0
        setProgressVisible(false)
        logTextView?.string = ""
        actionButton?.title = "Cancel"
        actionButton?.keyEquivalent = ""
        actionButton?.isEnabled = true
        applyActionButtonStyle(.cancel)
    }

    // MARK: - Panel Presentation
    func attachPanelToMainWindow(_ panel: NSPanel) {
        if let window = NSApp.mainWindow ?? NSApp.keyWindow {
            window.addChildWindow(panel, ordered: .above)
        }
    }

    func animatePanelIn(_ panel: NSPanel) {
        log.debug(#function)
        installEventMonitorIfNeeded()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    // MARK: - Label
    func makeLabel(font: NSFont, color: NSColor) -> NSTextField {
        let lbl = NSTextField(labelWithString: "")
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = font
        lbl.textColor = color
        lbl.maximumNumberOfLines = 1
        lbl.cell?.truncatesLastVisibleLine = true
        return lbl
    }

    // MARK: - Control State
    func applyActionButtonStyle(_ semantic: ProgressActionButton.Semantic) {
        guard let button = actionButton as? ProgressActionButton else { return }
        button.semantic = semantic
    }

    func setProgressVisible(_ visible: Bool) {
        progressIndicator?.isHidden = !visible
        progressHeightConstraint?.constant = visible ? Layout.progressHeight : 0
    }

    // MARK: - Appearance Refresh
    func refreshAppearance() {
        guard container != nil else { return }
        let a = appearance
        configureContainerAppearance()
        titleLabel?.font = a.titleFont
        titleLabel?.textColor = a.titleColor
        statusLabel?.font = a.statusFont
        statusLabel?.textColor = a.statusColor
        configureLogContainerAppearance()
        log.debug("[ProgressPanel] appearance refreshed")
    }
}
