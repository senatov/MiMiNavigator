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
    // MARK: - UI
    private var panel: NSPanel?
    private var container: NSView?
    private var iconView: NSImageView?
    private var titleLabel: NSTextField?
    private var statusLabel: NSTextField?
    private var logTextView: NSTextView?
    private var scrollView: NSScrollView?
    private var actionButton: NSButton?
    // MARK: - State
    private(set) var isCancelled = false
    private var lineCount = 0
    private var onCancel: (() -> Void)?
    private override init() { super.init() }
    private var appearance: ProgressPanelAppearance { .shared }
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
        iconView?.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        titleLabel?.stringValue = title
        statusLabel?.stringValue = status
        logTextView?.string = ""
        actionButton?.title = "Cancel"
        actionButton?.isEnabled = true
        centerInMainWindow()
        if let window = NSApp.mainWindow ?? NSApp.keyWindow {
            window.addChildWindow(panel, ordered: .above)
        }
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        log.debug("[ProgressPanel] \(#function) title='\(title)'")
    }
    // MARK: - Convenience: extraction
    func show(archiveName: String, destinationPath: String, cancelHandler: (() -> Void)? = nil) {
        show(icon: "archivebox.fill",
             title: "📦 \(archiveName)",
             status: "Extracting to \(abbreviatePath(destinationPath))…",
             cancelHandler: cancelHandler)
    }
    // MARK: - Convenience: packing
    func showPacking(archiveName: String, destinationPath: String, fileCount: Int, cancelHandler: (() -> Void)? = nil) {
        show(icon: "archivebox.fill",
             title: "📦 Packing → \(archiveName)",
             status: "Packing \(fileCount) item(s) to \(abbreviatePath(destinationPath))…",
             cancelHandler: cancelHandler)
    }
    // MARK: - Convenience: file operation
    func showFileOp(icon: String = "doc.on.doc", title: String, itemCount: Int, destination: String, cancelHandler: (() -> Void)? = nil) {
        show(icon: icon,
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
            .foregroundColor: appearance.logColor
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
            statusLabel?.stringValue = success
                ? "✅ Done — \(lineCount) item(s) processed"
                : "❌ Operation failed"
        }
        actionButton?.title = "OK"
        actionButton?.isEnabled = true
        onCancel = nil
        log.debug("[ProgressPanel] \(#function) success=\(success) lines=\(lineCount)")
    }
    // MARK: - Hide
    func hide() {
        guard let panel, panel.isVisible else { return }
        let parent = panel.parent
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
        })
    }
    // MARK: - Create Panel (autolayout, resizable)
    private func createPanel() {
        let a = appearance
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: a.panelWidth, height: a.panelHeight),
            styleMask: [.titled, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.hasShadow = true
        p.isOpaque = false
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.backgroundColor = .clear
        p.minSize = NSSize(width: ProgressPanelAppearance.defaultMinWidth,
                           height: ProgressPanelAppearance.defaultMinHeight)
        p.delegate = self
        guard let contentView = p.contentView else { return }
        // container fills content area
        let ct = NSView()
        ct.translatesAutoresizingMaskIntoConstraints = false
        ct.wantsLayer = true
        ct.layer?.backgroundColor = a.bgColor.cgColor
        ct.layer?.cornerRadius = 10
        ct.layer?.masksToBounds = true
        ct.layer?.borderColor = a.borderColor.cgColor
        ct.layer?.borderWidth = 0.5
        contentView.addSubview(ct)
        container = ct
        NSLayoutConstraint.activate([
            ct.topAnchor.constraint(equalTo: contentView.topAnchor),
            ct.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ct.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            ct.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        // icon
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "Progress")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        ct.addSubview(icon)
        iconView = icon
        // title
        let title = makeLabel(font: a.titleFont, color: a.titleColor)
        title.lineBreakMode = .byTruncatingMiddle
        ct.addSubview(title)
        titleLabel = title
        // status
        let status = makeLabel(font: a.statusFont, color: a.statusColor)
        status.lineBreakMode = .byTruncatingMiddle
        ct.addSubview(status)
        statusLabel = status
        // scroll + log
        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.drawsBackground = false
        sv.wantsLayer = true
        sv.layer?.cornerRadius = 4
        sv.layer?.borderColor = a.borderColor.cgColor
        sv.layer?.borderWidth = 0.5
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.isRichText = true
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        sv.documentView = tv
        ct.addSubview(sv)
        scrollView = sv
        logTextView = tv
        // action button
        let btn = NSButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.title = "Cancel"
        btn.bezelStyle = .rounded
        btn.controlSize = .small
        btn.target = self
        btn.action = #selector(actionButtonTapped)
        ct.addSubview(btn)
        actionButton = btn
        // MARK: - Constraints (autolayout)
        let pad: CGFloat = 14
        NSLayoutConstraint.activate([
            // icon top-left
            icon.leadingAnchor.constraint(equalTo: ct.leadingAnchor, constant: pad),
            icon.topAnchor.constraint(equalTo: ct.topAnchor, constant: 10),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),
            // title right of icon
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            title.trailingAnchor.constraint(equalTo: ct.trailingAnchor, constant: -pad),
            title.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            // status below title
            status.leadingAnchor.constraint(equalTo: ct.leadingAnchor, constant: pad),
            status.trailingAnchor.constraint(equalTo: ct.trailingAnchor, constant: -pad),
            status.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            // scrollView fills middle area
            sv.leadingAnchor.constraint(equalTo: ct.leadingAnchor, constant: pad),
            sv.trailingAnchor.constraint(equalTo: ct.trailingAnchor, constant: -pad),
            sv.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 8),
            sv.bottomAnchor.constraint(equalTo: btn.topAnchor, constant: -8),
            // button bottom-right
            btn.trailingAnchor.constraint(equalTo: ct.trailingAnchor, constant: -pad),
            btn.bottomAnchor.constraint(equalTo: ct.bottomAnchor, constant: -10),
            btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
        ])
        self.panel = p
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
        guard let ct = container else { return }
        let a = appearance
        ct.layer?.backgroundColor = a.bgColor.cgColor
        ct.layer?.borderColor = a.borderColor.cgColor
        titleLabel?.font = a.titleFont
        titleLabel?.textColor = a.titleColor
        statusLabel?.font = a.statusFont
        statusLabel?.textColor = a.statusColor
        scrollView?.layer?.borderColor = a.borderColor.cgColor
        log.debug("[ProgressPanel] appearance refreshed")
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
