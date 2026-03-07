// ArchiveProgressPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 07.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Floating NSPanel showing archive extraction progress — no title bar, no buttons.

import AppKit

// MARK: - Archive Progress Panel
/// Borderless floating panel that shows archive extraction progress.
/// Positioned center-screen, disappears automatically when extraction finishes.
@MainActor
final class ArchiveProgressPanel {

    // MARK: - Singleton
    static let shared = ArchiveProgressPanel()

    // MARK: - UI
    private var panel: NSPanel?
    private var archiveLabel: NSTextField?
    private var statusLabel: NSTextField?
    private var progressIndicator: NSProgressIndicator?

    private init() {}

    // MARK: - Show
    func show(archiveName: String, destinationPath: String) {
        if panel == nil { createPanel() }
        guard let panel else { return }
        archiveLabel?.stringValue = archiveName
        let shortDest = abbreviatePath(destinationPath)
        statusLabel?.stringValue = "Extracting to \(shortDest)…"
        progressIndicator?.startAnimation(nil)
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: sf.midX - panel.frame.width / 2, y: sf.midY - panel.frame.height / 2))
        }
        if let window = NSApp.keyWindow {
            window.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)
    }

    // MARK: - Update Status
    func updateStatus(_ text: String) {
        statusLabel?.stringValue = text
    }

    // MARK: - Hide
    func hide() {
        progressIndicator?.stopAnimation(nil)
        if let p = panel, let parent = p.parent {
            parent.removeChildWindow(p)
        }
        panel?.orderOut(nil)
    }

    // MARK: - Create Panel
    private func createPanel() {
        let w: CGFloat = 380
        let h: CGFloat = 90
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.hasShadow = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.isMovableByWindowBackground = true
        let content = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        let iv = NSImageView(frame: NSRect(x: 14, y: h - 60, width: 32, height: 32))
        iv.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "Archive")
        iv.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        iv.contentTintColor = .controlAccentColor
        content.addSubview(iv)
        let nameLabel = NSTextField(labelWithString: "")
        nameLabel.frame = NSRect(x: 54, y: h - 38, width: w - 68, height: 20)
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingMiddle
        content.addSubview(nameLabel)
        archiveLabel = nameLabel
        let sLabel = NSTextField(labelWithString: "Extracting…")
        sLabel.frame = NSRect(x: 54, y: h - 58, width: w - 68, height: 16)
        sLabel.font = NSFont.systemFont(ofSize: 11)
        sLabel.textColor = .secondaryLabelColor
        sLabel.lineBreakMode = .byTruncatingMiddle
        content.addSubview(sLabel)
        statusLabel = sLabel
        let prog = NSProgressIndicator(frame: NSRect(x: 14, y: 10, width: w - 28, height: 12))
        prog.style = .bar
        prog.isIndeterminate = true
        prog.controlSize = .small
        content.addSubview(prog)
        progressIndicator = prog
        p.contentView = content
        self.panel = p
    }

    // MARK: - Abbreviate Path
    private func abbreviatePath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        if path.count > 50 {
            return "…" + path.suffix(45)
        }
        return path
    }
}
