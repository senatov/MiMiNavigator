// ArchiveProgressPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 07.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Modal sheet-style panel for archive extraction progress — centered in main window.

import AppKit

// MARK: - Archive Progress Panel
/// Modal-style panel centered in the main window during archive extraction.
/// No title bar, no buttons — just archive name, status, and progress bar.
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
        centerInMainWindow()
        if let window = NSApp.mainWindow ?? NSApp.keyWindow {
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

    // MARK: - Center In Main Window
    private func centerInMainWindow() {
        guard let panel else { return }
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow else { return }
        let wf = window.frame
        let pf = panel.frame
        let x = wf.midX - pf.width / 2
        let y = wf.midY - pf.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Create Panel
    private func createPanel() {
        let w: CGFloat = 360
        let h: CGFloat = 88
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
        p.isMovableByWindowBackground = false
        // Rounded semi-transparent background
        let content = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        content.material = .hudWindow
        content.blendingMode = .behindWindow
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = 12
        content.layer?.masksToBounds = true
        // Archive icon
        let iv = NSImageView(frame: NSRect(x: 16, y: h - 56, width: 28, height: 28))
        iv.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "Archive")
        iv.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        iv.contentTintColor = .controlAccentColor
        content.addSubview(iv)
        // Archive name — system font 13, regular weight
        let nameLabel = NSTextField(labelWithString: "")
        nameLabel.frame = NSRect(x: 52, y: h - 34, width: w - 68, height: 18)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingMiddle
        content.addSubview(nameLabel)
        archiveLabel = nameLabel
        // Status line — system font 11
        let sLabel = NSTextField(labelWithString: "Extracting…")
        sLabel.frame = NSRect(x: 52, y: h - 54, width: w - 68, height: 16)
        sLabel.font = NSFont.systemFont(ofSize: 11)
        sLabel.textColor = .secondaryLabelColor
        sLabel.lineBreakMode = .byTruncatingMiddle
        content.addSubview(sLabel)
        statusLabel = sLabel
        // Progress bar
        let prog = NSProgressIndicator(frame: NSRect(x: 16, y: 10, width: w - 32, height: 10))
        prog.style = .bar
        prog.isIndeterminate = true
        prog.controlSize = .small
        content.addSubview(prog)
        progressIndicator = prog
        p.contentView = content
        p.backgroundColor = .clear
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
