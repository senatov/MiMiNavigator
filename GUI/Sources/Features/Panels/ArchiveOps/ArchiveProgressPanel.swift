// ArchiveProgressPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 07.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: InfoPopupController-style HUD for archive extraction —
//   scrollable log of extracted files, status line, Cancel→OK button.

import AppKit

// MARK: - Archive Progress Panel

@MainActor
final class ArchiveProgressPanel {

    // MARK: - Singleton
    static let shared = ArchiveProgressPanel()

    // MARK: - UI
    private var panel: NSPanel?
    private var titleLabel: NSTextField?
    private var statusLabel: NSTextField?
    private var logTextView: NSTextView?
    private var scrollView: NSScrollView?
    private var actionButton: NSButton?

    // MARK: - State
    private(set) var isCancelled = false
    private var lineCount = 0
    private var onCancel: (() -> Void)?

    private init() {}

    // MARK: - Show

    func show(archiveName: String, destinationPath: String, cancelHandler: (() -> Void)? = nil) {
        isCancelled = false
        lineCount = 0
        onCancel = cancelHandler

        if panel == nil { createPanel() }
        guard let panel else { return }

        titleLabel?.stringValue = "📦 \(archiveName)"
        let shortDest = abbreviatePath(destinationPath)
        statusLabel?.stringValue = "Extracting to \(shortDest)…"
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
        log.debug("[ArchiveProgressPanel] shown for \(archiveName)")
    }

    // MARK: - Append Log Line

    func appendLog(_ line: String) {
        guard let tv = logTextView else { return }
        lineCount += 1
        let entry = "\(lineCount). \(line)\n"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: InfoPopupController.valueColor
        ]
        tv.textStorage?.append(NSAttributedString(string: entry, attributes: attrs))
        tv.scrollToEndOfDocument(nil)
    }

    // MARK: - Update Status

    func updateStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    // MARK: - Finish (Cancel → OK)

    func finish(success: Bool, message: String? = nil) {
        if let msg = message {
            statusLabel?.stringValue = msg
        } else {
            statusLabel?.stringValue = success
                ? "✅ Done — \(lineCount) file(s) extracted"
                : "❌ Extraction failed"
        }
        actionButton?.title = "OK"
        actionButton?.isEnabled = true
        onCancel = nil
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

    // MARK: - Create Panel

    private func createPanel() {
        let w: CGFloat = 440
        let h: CGFloat = 320

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.hasShadow = true
        p.isOpaque = false
        p.level = .modalPanel
        p.isMovableByWindowBackground = true
        p.backgroundColor = .clear

        // Container — warm yellow HUD bg like InfoPopupController
        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = InfoPopupController.bgColor.cgColor
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.layer?.borderColor = InfoPopupController.borderColor.cgColor
        container.layer?.borderWidth = 0.5
        p.contentView = container

        // Archive icon
        let icon = NSImageView(frame: NSRect(x: 14, y: h - 34, width: 22, height: 22))
        icon.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "Archive")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        container.addSubview(icon)

        // Title
        let title = makeLabel(
            frame: NSRect(x: 42, y: h - 32, width: w - 56, height: 18),
            font: InfoPopupController.titleFont,
            color: InfoPopupController.titleColor
        )
        title.lineBreakMode = .byTruncatingMiddle
        container.addSubview(title)
        titleLabel = title

        // Status
        let status = makeLabel(
            frame: NSRect(x: 14, y: h - 54, width: w - 28, height: 16),
            font: InfoPopupController.labelFont,
            color: InfoPopupController.labelColor
        )
        status.lineBreakMode = .byTruncatingMiddle
        container.addSubview(status)
        statusLabel = status

        // Scrollable log area
        let logTop = h - 64
        let logH = logTop - 50
        let sv = NSScrollView(frame: NSRect(x: 14, y: 46, width: w - 28, height: logH))
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.drawsBackground = true
        sv.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.5)
        sv.wantsLayer = true
        sv.layer?.cornerRadius = 4
        sv.layer?.borderColor = NSColor(calibratedWhite: 0.75, alpha: 0.4).cgColor
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
        container.addSubview(sv)
        scrollView = sv
        logTextView = tv

        // Action button (Cancel → OK)
        let btn = NSButton(frame: NSRect(x: w - 90, y: 10, width: 76, height: 28))
        btn.title = "Cancel"
        btn.bezelStyle = .rounded
        btn.target = self
        btn.action = #selector(actionButtonTapped)
        container.addSubview(btn)
        actionButton = btn

        self.panel = p
    }

    // MARK: - Helpers

    private func makeLabel(frame: NSRect, font: NSFont, color: NSColor) -> NSTextField {
        let lbl = NSTextField(frame: frame)
        lbl.isBordered = false
        lbl.isEditable = false
        lbl.isSelectable = false
        lbl.backgroundColor = .clear
        lbl.font = font
        lbl.textColor = color
        return lbl
    }

    private func centerInMainWindow() {
        guard let panel else { return }
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow else { return }
        let wf = window.frame
        let pf = panel.frame
        panel.setFrameOrigin(NSPoint(x: wf.midX - pf.width / 2, y: wf.midY - pf.height / 2))
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path.count > 50 ? "…" + path.suffix(45) : path
    }

    // MARK: - Button Action

    @objc private func actionButtonTapped() {
        if actionButton?.title == "OK" {
            hide()
        } else {
            isCancelled = true
            statusLabel?.stringValue = "⏹ Cancelling…"
            actionButton?.isEnabled = false
            onCancel?()
        }
    }
}
