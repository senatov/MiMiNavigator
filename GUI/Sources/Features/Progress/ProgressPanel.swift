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
    private enum Layout {
        static let containerCornerRadius: CGFloat = 12
        static let outerPadding: CGFloat = 14
        static let topInset: CGFloat = 10
        static let iconSize: CGFloat = 22
        static let titleSpacing: CGFloat = 8
        static let statusTopSpacing: CGFloat = 6
        static let logTopSpacing: CGFloat = 8
        static let buttonBottomInset: CGFloat = 10
        static let logCornerRadius: CGFloat = 6
        static let logInset = NSSize(width: 4, height: 4)
        static let logLinePadding: CGFloat = 0
        static let borderWidth: CGFloat = 0.5
        static let buttonMinWidth: CGFloat = 92
        static let buttonHeight: CGFloat = 30
    }


    // MARK: - UI
    private var panel: NSPanel?
    private var container: NSView?
    private var iconView: NSImageView?
    private var titleLabel: NSTextField?
    private var statusLabel: NSTextField?
    private var logTextView: NSTextView?
    private var scrollView: NSScrollView?
    private var actionButton: NSButton?
    private var backgroundEffectView: NSVisualEffectView?
    private var logBackgroundEffectView: NSVisualEffectView?
    // MARK: - State
    private(set) var isCancelled = false
    private var lineCount = 0
    private var onCancel: (() -> Void)?
    private override init() { super.init() }
    private var appearance: ProgressPanelAppearance { .shared }

    // MARK: - Compatibility Helpers
    func reset(title: String, message: String, icon: String = "archivebox.fill") {
        if panel == nil { createPanel() }
        isCancelled = false
        lineCount = 0
        resetContent(icon: icon, title: title, status: message)
    }

    func setCancelHandler(_ handler: (() -> Void)?) {
        onCancel = handler
        actionButton?.isEnabled = true
        if actionButton?.title != "OK" {
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
        cancelHandler: (() -> Void)? = nil
    ) {
        isCancelled = false
        lineCount = 0
        onCancel = cancelHandler
        if panel == nil { createPanel() }
        guard let panel else { return }
        resetContent(icon: icon, title: title, status: status)
        centerInMainWindow()
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
            cancelHandler: cancelHandler)
    }
    // MARK: - Convenience: packing
    func showPacking(archiveName: String, destinationPath: String, fileCount: Int, cancelHandler: (() -> Void)? = nil) {
        show(
            icon: "archivebox.fill",
            title: "📦 Packing → \(archiveName)",
            status: "Packing \(fileCount) item(s) to \(abbreviatePath(destinationPath))…",
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
    // MARK: - Update Status
    func updateStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    // MARK: - Update (preferred for live progress)
    func update(text: String) {
        guard panel?.isVisible == true else { return }
        statusLabel?.stringValue = text
    }
    // MARK: - Finish (Cancel → OK)
    func finish(success: Bool, message: String? = nil) {
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
        applyActionButtonStyle(.confirm)
        onCancel = nil
        log.debug("[ProgressPanel] \(#function) success=\(success) lines=\(lineCount)")
    }

    func finish(success: Bool, details: String?) {
        finish(success: success, message: details)
    }
    // MARK: - Hide
    func hide() {
        guard let panel, panel.isVisible else { return }
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
                }
            })
    }

    private func makeContainerView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.cornerRadius = Layout.containerCornerRadius
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = Layout.borderWidth
        return view
    }

    private func makeBackgroundEffectView() -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = Layout.containerCornerRadius
        effectView.layer?.masksToBounds = true
        return effectView
    }

    private func makeLogEffectView() -> NSVisualEffectView {
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

    private func configureContainerAppearance() {
        let a = appearance
        container?.layer?.backgroundColor = a.bgColor.withAlphaComponent(0.92).cgColor
        container?.layer?.borderColor = a.borderColor.cgColor
        backgroundEffectView?.alphaValue = 1
    }

    private func configureLogContainerAppearance() {
        let a = appearance
        scrollView?.layer?.cornerRadius = Layout.logCornerRadius
        scrollView?.layer?.borderColor = a.borderColor.cgColor
        scrollView?.layer?.borderWidth = Layout.borderWidth
        logBackgroundEffectView?.alphaValue = 0.72
    }

    private func resetContent(icon: String, title: String, status: String) {
        iconView?.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        titleLabel?.stringValue = title
        statusLabel?.stringValue = status
        logTextView?.string = ""
        actionButton?.title = "Cancel"
        actionButton?.isEnabled = true
        applyActionButtonStyle(.cancel)
    }

    private func attachPanelToMainWindow(_ panel: NSPanel) {
        if let window = NSApp.mainWindow ?? NSApp.keyWindow {
            window.addChildWindow(panel, ordered: .above)
        }
    }

    private func animatePanelIn(_ panel: NSPanel) {
        log.debug(#function)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    // MARK: - Create Panel (autolayout, resizable)
    private func createPanel() {
        let a = appearance
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: a.panelWidth, height: a.panelHeight),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: true
        )
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
        panel.minSize = NSSize(
            width: ProgressPanelAppearance.defaultMinWidth,
            height: ProgressPanelAppearance.defaultMinHeight
        )
        panel.delegate = self

        guard let contentView = panel.contentView else { return }

        let containerView = makeContainerView()
        let backgroundView = makeBackgroundEffectView()
        contentView.addSubview(containerView)
        containerView.addSubview(backgroundView, positioned: .below, relativeTo: nil)

        container = containerView
        backgroundEffectView = backgroundView

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "Progress")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        containerView.addSubview(icon)
        iconView = icon

        let title = makeLabel(font: a.titleFont, color: a.titleColor)
        title.lineBreakMode = .byTruncatingMiddle
        containerView.addSubview(title)
        titleLabel = title

        let status = makeLabel(font: a.statusFont, color: a.statusColor)
        status.lineBreakMode = .byTruncatingMiddle
        containerView.addSubview(status)
        statusLabel = status

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
        textView.isEditable = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.allowsUndo = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = Layout.logInset
        textView.textContainer?.lineFragmentPadding = Layout.logLinePadding
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let menu = NSMenu()
        menu.addItem(withTitle: "Copy All", action: #selector(copyAll), keyEquivalent: "")
        textView.menu = menu
        scrollView.documentView = textView
        containerView.addSubview(scrollView)
        self.scrollView = scrollView
        logTextView = textView

        NSLayoutConstraint.activate([
            logEffectView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            logEffectView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            logEffectView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            logEffectView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
        ])

        let button = ProgressActionButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = "Cancel"
        button.target = self
        button.action = #selector(actionButtonTapped)
        containerView.addSubview(button)
        actionButton = button
        applyActionButtonStyle(.cancel)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Layout.outerPadding),
            icon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Layout.topInset),
            icon.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            icon.heightAnchor.constraint(equalToConstant: Layout.iconSize),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: Layout.titleSpacing),
            title.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            title.centerYAnchor.constraint(equalTo: icon.centerYAnchor),

            status.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Layout.outerPadding),
            status.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            status.topAnchor.constraint(equalTo: title.bottomAnchor, constant: Layout.statusTopSpacing),

            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Layout.outerPadding),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            scrollView.topAnchor.constraint(equalTo: status.bottomAnchor, constant: Layout.logTopSpacing),
            scrollView.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -Layout.logTopSpacing),

            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Layout.buttonBottomInset),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.buttonMinWidth),
            button.heightAnchor.constraint(equalToConstant: Layout.buttonHeight),
        ])

        self.panel = panel
        configureContainerAppearance()
        configureLogContainerAppearance()
    }
    // MARK: - Copy to Clipboard
    func copyAllToClipboard() {
        guard let text = logTextView?.string, !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        log.debug("[ProgressPanel] copied log to clipboard")
    }
    @objc private func copyAll() {
        copyAllToClipboard()
    }
    // MARK: - Action Button
    @objc private func actionButtonTapped() {
        if actionButton?.title == "OK" {
            hide()
            return
        }
        isCancelled = true
        onCancel?()
        actionButton?.isEnabled = false
        statusLabel?.stringValue = "⏳ Cancelling…"
        log.debug("[ProgressPanel] cancel requested")
    }
    // MARK: - Center in Main Window
    private func centerInMainWindow() {
        guard let panel else { return }
        if let mainFrame = (NSApp.mainWindow ?? NSApp.keyWindow)?.frame {
            let x = mainFrame.midX - panel.frame.width / 2
            let y = mainFrame.midY - panel.frame.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
    }
    // MARK: - Make Label Helper
    private func makeLabel(font: NSFont, color: NSColor) -> NSTextField {
        let lbl = NSTextField(labelWithString: "")
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = font
        lbl.textColor = color
        lbl.maximumNumberOfLines = 1
        lbl.cell?.truncatesLastVisibleLine = true
        return lbl
    }

    private func applyActionButtonStyle(_ semantic: ProgressActionButton.Semantic) {
        guard let button = actionButton as? ProgressActionButton else { return }
        button.semantic = semantic
    }
    // MARK: - Abbreviate Path
    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
    // MARK: - Refresh Appearance (call after Settings change)
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

final class ProgressActionButton: NSButton {
    enum Semantic {
        case cancel
        case confirm

        var borderColor: NSColor {
            switch self {
            case .cancel: return NSColor.systemRed.withAlphaComponent(0.9)
            case .confirm: return NSColor.systemGreen.withAlphaComponent(0.9)
            }
        }

        var titleColor: NSColor {
            switch self {
            case .cancel: return NSColor.systemRed.blended(withFraction: 0.35, of: .labelColor) ?? .labelColor
            case .confirm: return NSColor.systemGreen.blended(withFraction: 0.35, of: .labelColor) ?? .labelColor
            }
        }

        var glowColor: NSColor {
            switch self {
            case .cancel: return NSColor.systemRed.withAlphaComponent(0.25)
            case .confirm: return NSColor.systemGreen.withAlphaComponent(0.25)
            }
        }
    }

    var semantic: Semantic = .cancel {
        didSet {
            needsLayout = true
            updateAppearance()
        }
    }

    private let baseGradient = CAGradientLayer()
    private let glossGradient = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    private let innerShadowLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layout() {
        super.layout()
        guard let layer else { return }

        let buttonBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let shapePath = CGPath(
            roundedRect: buttonBounds,
            cornerWidth: 9,
            cornerHeight: 9,
            transform: nil
        )

        baseGradient.frame = bounds
        glossGradient.frame = bounds
        borderLayer.frame = bounds
        borderLayer.path = shapePath
        innerShadowLayer.frame = bounds
        innerShadowLayer.path = shapePath

        layer.shadowPath = shapePath
        updateAppearance()
    }

    override func setButtonType(_ buttonType: NSButton.ButtonType) {
        super.setButtonType(buttonType)
        updateAppearance()
    }

    override func updateLayer() {
        super.updateLayer()
        updateAppearance()
    }

    private func configure() {
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryPushIn)
        focusRingType = .none
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        imagePosition = .noImage
        font = .systemFont(ofSize: 12.5, weight: .semibold)
        contentTintColor = semantic.titleColor

        guard let layer else { return }
        layer.cornerRadius = 9
        layer.masksToBounds = false
        layer.backgroundColor = NSColor.clear.cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: -2)

        baseGradient.colors = [
            NSColor.white.withAlphaComponent(0.62).cgColor,
            NSColor(calibratedWhite: 0.92, alpha: 0.76).cgColor,
            NSColor(calibratedWhite: 0.82, alpha: 0.92).cgColor
        ]
        baseGradient.locations = [0, 0.42, 1]
        baseGradient.startPoint = CGPoint(x: 0.5, y: 1)
        baseGradient.endPoint = CGPoint(x: 0.5, y: 0)
        baseGradient.cornerRadius = 9

        glossGradient.colors = [
            NSColor.white.withAlphaComponent(0.52).cgColor,
            NSColor.white.withAlphaComponent(0.12).cgColor,
            NSColor.clear.cgColor
        ]
        glossGradient.locations = [0, 0.22, 0.8]
        glossGradient.startPoint = CGPoint(x: 0.5, y: 1)
        glossGradient.endPoint = CGPoint(x: 0.5, y: 0)
        glossGradient.cornerRadius = 9

        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.lineWidth = 1

        innerShadowLayer.fillColor = NSColor.clear.cgColor
        innerShadowLayer.strokeColor = NSColor.white.withAlphaComponent(0.35).cgColor
        innerShadowLayer.lineWidth = 1
        innerShadowLayer.opacity = 0.95

        layer.addSublayer(baseGradient)
        layer.addSublayer(glossGradient)
        layer.addSublayer(innerShadowLayer)
        layer.addSublayer(borderLayer)

        updateAppearance()
    }

    private func updateAppearance() {
        let isPressed = cell?.isHighlighted ?? false
        let scale: CGFloat = isPressed ? 0.965 : 1

        layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        layer?.shadowColor = semantic.glowColor.cgColor
        layer?.shadowOpacity = isPressed ? 0.18 : 0.34
        layer?.shadowRadius = isPressed ? 2 : 4
        layer?.shadowOffset = CGSize(width: 0, height: isPressed ? -1 : -2)

        borderLayer.strokeColor = semantic.borderColor.cgColor
        innerShadowLayer.opacity = isEnabled ? 0.95 : 0.45

        let topAlpha: CGFloat = isEnabled ? (isPressed ? 0.48 : 0.62) : 0.28
        let midAlpha: CGFloat = isEnabled ? (isPressed ? 0.62 : 0.76) : 0.36
        let bottomAlpha: CGFloat = isEnabled ? (isPressed ? 0.78 : 0.92) : 0.48
        baseGradient.colors = [
            NSColor.white.withAlphaComponent(topAlpha).cgColor,
            NSColor(calibratedWhite: 0.92, alpha: midAlpha).cgColor,
            NSColor(calibratedWhite: 0.82, alpha: bottomAlpha).cgColor
        ]
        glossGradient.opacity = isPressed ? 0.55 : 1

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font ?? NSFont.systemFont(ofSize: 12.5, weight: .semibold),
                .foregroundColor: isEnabled ? semantic.titleColor : NSColor.disabledControlTextColor,
                .paragraphStyle: paragraph,
                .kern: 0.15
            ]
        )
    }
}

// MARK: - NSWindowDelegate
extension ProgressPanel: NSWindowDelegate {
    nonisolated func windowDidResize(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard let panel else { return }
            let size = panel.frame.size
            appearance.updateSize(width: size.width, height: size.height)
        }
    }
}

private final class CopyableTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
            self.copy(self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
