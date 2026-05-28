// ProgressPanel+Create.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ProgressPanel construction and Auto Layout constraints.

import AppKit

// MARK: - Create Panel

extension ProgressPanel {
    // MARK: - Create Panel
    func createPanel() {
        let a = appearance
        let panel = ProgressPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: a.panelWidth, height: a.panelHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        configurePanel(panel)
        guard let contentView = panel.contentView else { return }
        let containerView = makeContainerView()
        let backgroundView = makeBackgroundEffectView()
        contentView.addSubview(containerView)
        containerView.addSubview(backgroundView, positioned: .below, relativeTo: nil)
        container = containerView
        backgroundEffectView = backgroundView
        pinContainer(containerView, backgroundView: backgroundView, contentView: contentView)
        addHeader(to: containerView, appearance: a)
        addProgressBar(to: containerView)
        addLogView(to: containerView)
        addActionButton(to: containerView)
        activateMainConstraints(containerView: containerView)
        self.panel = panel
        configureContainerAppearance()
        configureLogContainerAppearance()
    }

    // MARK: - Configure Panel
    func configurePanel(_ panel: NSPanel) {
        panel.becomesKeyOnlyIfNeeded = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.acceptsMouseMovedEvents = true
        panel.minSize = NSSize(width: ProgressPanelAppearance.defaultMinWidth, height: Layout.minimumPanelHeight)
        if let progressPanel = panel as? ProgressPanelWindow {
            progressPanel.onInteraction = { [weak self] in
                Task { @MainActor in
                    self?.registerUserInteraction(source: "window")
                }
            }
            progressPanel.onPrimaryMouseDown = { [weak self] event in
                Task { @MainActor in
                    self?.handlePanelMouseDownFallback(event)
                }
            }
            progressPanel.onPrimaryMouseUp = { [weak self] event in
                Task { @MainActor in
                    self?.handlePanelMouseUpFallback(event)
                }
            }
        }
        panel.delegate = self
    }

    // MARK: - Add Header
    func addHeader(to containerView: NSView, appearance: ProgressPanelAppearance) {
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "Progress")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        containerView.addSubview(icon)
        iconView = icon
        let title = makeLabel(font: appearance.titleFont, color: appearance.titleColor)
        title.lineBreakMode = .byTruncatingMiddle
        containerView.addSubview(title)
        titleLabel = title
        let status = makeLabel(font: appearance.statusFont, color: appearance.statusColor)
        status.lineBreakMode = .byTruncatingMiddle
        containerView.addSubview(status)
        statusLabel = status
    }

    // MARK: - Add Progress Bar
    func addProgressBar(to containerView: NSView) {
        let progress = NSProgressIndicator()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = 0
        progress.controlSize = .small
        progress.style = .bar
        progress.isDisplayedWhenStopped = false
        containerView.addSubview(progress)
        progressIndicator = progress
    }

    // MARK: - Add Log View
    func addLogView(to containerView: NSView) {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        let logEffectView = makeLogEffectView()
        scrollView.addSubview(logEffectView, positioned: .below, relativeTo: nil)
        logBackgroundEffectView = logEffectView
        let textView = CopyableTextView()
        textView.configureForProgressLog(insets: Layout.logInset, linePadding: Layout.logLinePadding)
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy All", action: #selector(copyAll), keyEquivalent: "")
        textView.menu = menu
        scrollView.documentView = textView
        containerView.addSubview(scrollView)
        self.scrollView = scrollView
        logTextView = textView
        pinLogBackground(logEffectView, to: scrollView)
    }

    // MARK: - Add Action Button
    func addActionButton(to containerView: NSView) {
        let button = ProgressActionButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = "Cancel"
        button.onPress = { [weak self] in
            Task { @MainActor in
                self?.actionButtonTapped()
            }
        }
        containerView.addSubview(button)
        actionButton = button
        applyActionButtonStyle(.cancel)
    }
}
