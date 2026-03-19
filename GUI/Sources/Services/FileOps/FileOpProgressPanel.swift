// FileOpProgressPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Non-modal floating NSPanel showing file operation progress — like ProgressPanel

import AppKit

// MARK: - File Operation Progress Panel
/// Non-modal floating panel showing copy/move progress.
/// Re-uses the same visual style as ProgressPanel (HUD, rounded, no title bar).
@MainActor
final class FileOpProgressPanel {

    static let shared = FileOpProgressPanel()

    // MARK: - UI elements
    private var panel: NSPanel?
    private var titleLabel: NSTextField?
    private var fileLabel: NSTextField?
    private var bytesLabel: NSTextField?
    private var progressBar: NSProgressIndicator?
    private var stopButton: NSButton?
    private var okButton: NSButton?

    // MARK: - State
    private var progress: FileOpProgress?
    private var updateTimer: Timer?
    private var waitingForOK = false

    private init() {}

    // MARK: - Show

    func show(progress: FileOpProgress) {
        self.progress = progress
        self.waitingForOK = false
        if panel == nil { createPanel() }
        guard let panel else { return }

        titleLabel?.stringValue = progress.operationType.title
        fileLabel?.stringValue = ""
        bytesLabel?.stringValue = ""
        progressBar?.isIndeterminate = false
        progressBar?.doubleValue = 0
        progressBar?.startAnimation(nil)
        stopButton?.isHidden = false
        okButton?.isHidden = true

        centerInMainWindow()
        if let window = NSApp.mainWindow ?? NSApp.keyWindow {
            window.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)

        // Throttled UI updates ~10/sec
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUI()
            }
        }
    }

    // MARK: - Hide

    func hide() {
        updateTimer?.invalidate()
        updateTimer = nil
        progressBar?.stopAnimation(nil)
        if let p = panel, let parent = p.parent {
            parent.removeChildWindow(p)
        }
        panel?.orderOut(nil)
        progress = nil
    }

    // MARK: - Refresh UI

    private func refreshUI() {
        guard let progress else { return }
        titleLabel?.stringValue = progress.statusText
        fileLabel?.stringValue = progress.currentFileName
        bytesLabel?.stringValue = progress.bytesText
        progressBar?.doubleValue = progress.fraction * 100.0

        if progress.isCompleted || progress.isCancelled {
            // Show OK button, hide Stop button
            stopButton?.isHidden = true
            okButton?.isHidden = false
            waitingForOK = true
            
            // Update title to show completion
            if progress.isCancelled {
                titleLabel?.stringValue = "❌ Cancelled"
            } else if !progress.errors.isEmpty {
                titleLabel?.stringValue = "⚠️ Completed with \(progress.errors.count) error(s)"
            } else {
                titleLabel?.stringValue = "✅ Completed: \(progress.processedFiles) files"
            }
        }
    }

    // MARK: - Center

    private func centerInMainWindow() {
        guard let panel else { return }
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow else { return }
        let wf = window.frame
        let pf = panel.frame
        panel.setFrameOrigin(NSPoint(
            x: wf.midX - pf.width / 2,
            y: wf.midY - pf.height / 2
        ))
    }

    // MARK: - Create Panel

    private func createPanel() {
        let w: CGFloat = 380
        let h: CGFloat = 110

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.hidesOnDeactivate = true   // Hide when app loses focus, reappear when regains
        p.hasShadow = true
        p.isOpaque = false
        p.level = .floating          // Non-modal, stays above main window but not system-wide
        p.isMovableByWindowBackground = true
        p.backgroundColor = .clear

        // Vibrancy background
        let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12
        bg.layer?.masksToBounds = true

        // Icon
        let icon = NSImageView(frame: NSRect(x: 14, y: h - 36, width: 22, height: 22))
        icon.image = NSImage(systemSymbolName: "doc.on.doc.fill", accessibilityDescription: "File operation")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        icon.contentTintColor = .controlAccentColor
        bg.addSubview(icon)

        // Title (operation type + counter)
        let tLabel = NSTextField(labelWithString: "")
        tLabel.frame = NSRect(x: 42, y: h - 30, width: w - 100, height: 16)
        tLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        tLabel.textColor = .labelColor
        tLabel.lineBreakMode = .byTruncatingMiddle
        bg.addSubview(tLabel)
        titleLabel = tLabel

        // Current file name
        let fLabel = NSTextField(labelWithString: "")
        fLabel.frame = NSRect(x: 42, y: h - 50, width: w - 58, height: 14)
        fLabel.font = NSFont.systemFont(ofSize: 11)
        fLabel.textColor = .secondaryLabelColor
        fLabel.lineBreakMode = .byTruncatingMiddle
        bg.addSubview(fLabel)
        fileLabel = fLabel

        // Progress bar
        let prog = NSProgressIndicator(frame: NSRect(x: 14, y: 26, width: w - 28, height: 10))
        prog.style = .bar
        prog.isIndeterminate = false
        prog.minValue = 0
        prog.maxValue = 100
        prog.controlSize = .small
        bg.addSubview(prog)
        progressBar = prog

        // Bytes label (left-aligned under progress)
        let bLabel = NSTextField(labelWithString: "")
        bLabel.frame = NSRect(x: 14, y: 8, width: w - 90, height: 14)
        bLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        bLabel.textColor = .tertiaryLabelColor
        bg.addSubview(bLabel)
        bytesLabel = bLabel

        // Stop button
        let btn = NSButton(title: "Stop", target: nil, action: #selector(stopClicked))
        btn.frame = NSRect(x: w - 70, y: 4, width: 56, height: 22)
        btn.bezelStyle = .rounded
        btn.controlSize = .small
        btn.target = self
        bg.addSubview(btn)
        stopButton = btn
        
        // OK button (hidden initially, shown on completion)
        let okBtn = NSButton(title: "OK", target: nil, action: #selector(okClicked))
        okBtn.frame = NSRect(x: w - 70, y: 4, width: 56, height: 22)
        okBtn.bezelStyle = .rounded
        okBtn.controlSize = .small
        okBtn.target = self
        okBtn.isHidden = true
        bg.addSubview(okBtn)
        okButton = okBtn

        p.contentView = bg
        self.panel = p
    }

    @objc private func stopClicked() {
        progress?.cancel()
        log.info("[FileOpProgressPanel] stop clicked")
    }
    
    @objc private func okClicked() {
        log.info("[FileOpProgressPanel] OK clicked, hiding panel")
        hide()
    }
}
