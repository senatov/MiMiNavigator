// OperationProgressPanel.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Floating HUD panel showing live progress of lengthy file operations.
//   Extends InfoPopupController with progress bar, speed, ETA, current file display.
//   Supports pause/cancel controls.

import AppKit
import Foundation

// MARK: - Operation Progress Panel

@MainActor
final class OperationProgressPanel {
    
    // MARK: - Singleton for active operation
    static var active: OperationProgressPanel?
    
    // MARK: - Panel components
    private var panel: NSPanel?
    private var containerView: NSView?
    private var iconView: NSImageView?
    private var titleLabel: NSTextField?
    private var progressBar: NSProgressIndicator?
    private var percentLabel: NSTextField?
    private var currentFileLabel: NSTextField?
    private var statsLabel: NSTextField?
    private var speedLabel: NSTextField?
    private var etaLabel: NSTextField?
    private var errorLabel: NSTextField?
    private var pauseButton: NSButton?
    private var cancelButton: NSButton?
    
    // MARK: - State
    private weak var operation: OperationProgress?
    private var updateTimer: Timer?
    
    var onPause: (() -> Void)?
    var onCancel: (() -> Void)?
    
    // MARK: - Constants
    private enum Layout {
        static let width: CGFloat = 380
        static let height: CGFloat = 180
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 8
    }
    
    private enum Colors {
        static let bg = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 0.95)
        static let title = NSColor.white
        static let primary = NSColor(white: 0.9, alpha: 1)
        static let secondary = NSColor(white: 0.6, alpha: 1)
        static let accent = NSColor.systemBlue
        static let error = NSColor.systemRed
    }
    
    // MARK: - Init
    init() {}
    
    // MARK: - Show
    
    /// Show progress panel for an operation, centered in main window
    func show(for operation: OperationProgress) {
        self.operation = operation
        Self.active = self
        
        if panel == nil {
            buildPanel()
        }
        
        guard let panel else { return }
        
        // Position center of main window
        if let window = NSApp.mainWindow ?? NSApp.keyWindow {
            let winFrame = window.frame
            let x = winFrame.midX - Layout.width / 2
            let y = winFrame.midY - Layout.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            window.addChildWindow(panel, ordered: .above)
        }
        
        updateUI()
        panel.alphaValue = 0
        panel.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateUI()
            }
        }
        
        log.info("[ProgressPanel] shown for \(operation.operationType.rawValue)")
    }
    
    // MARK: - Hide
    
    func hide() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        guard let panel, panel.isVisible else { return }
        
        let parent = panel.parent
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                parent?.removeChildWindow(panel)
                panel.orderOut(nil)
                Self.active = nil
            }
        })
        
        log.info("[ProgressPanel] hidden")
    }
    
    // MARK: - Update UI
    
    private func updateUI() {
        guard let op = operation else { return }
        
        // Title
        let est = op.estimate
        let totalFiles = est?.totalFiles ?? 0
        titleLabel?.stringValue = "\(op.operationType.verb): \(op.processedFiles) / \(totalFiles) files"
        
        // Progress bar
        progressBar?.doubleValue = op.progress * 100
        percentLabel?.stringValue = "\(op.percentComplete)%"
        
        // Current file (truncate if too long)
        let filename = op.currentFile
        let maxLen = 50
        let displayName = filename.count > maxLen 
            ? "…" + filename.suffix(maxLen - 1)
            : filename
        currentFileLabel?.stringValue = displayName
        
        // Stats
        let totalSize = est?.formattedSize ?? "?"
        statsLabel?.stringValue = "Transferred: \(op.formattedProcessed) / \(totalSize)"
        
        // Speed & ETA
        speedLabel?.stringValue = "Speed: \(op.formattedSpeed)"
        etaLabel?.stringValue = "Remaining: \(op.formattedRemainingTime)"
        
        // Errors
        if op.errors.isEmpty {
            errorLabel?.isHidden = true
        } else {
            errorLabel?.isHidden = false
            errorLabel?.stringValue = "⚠️ \(op.errors.count) error(s)"
        }
        
        // State-based UI
        switch op.state {
        case .paused:
            pauseButton?.title = "Resume"
        case .running:
            pauseButton?.title = "Pause"
        case .completed:
            hide()
        case .failed:
            titleLabel?.stringValue = "❌ Operation Failed"
            pauseButton?.isEnabled = false
        default:
            break
        }
    }
    
    // MARK: - Build Panel
    
    private func buildPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.height),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.title = "Operation Progress"
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.hasShadow = true
        p.level = .floating
        p.backgroundColor = Colors.bg
        
        let container = NSView(frame: p.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        p.contentView?.addSubview(container)
        self.containerView = container
        
        var y = Layout.height - Layout.padding
        
        // Icon + Title row
        let icon = NSImageView(frame: NSRect(x: Layout.padding, y: y - 24, width: 24, height: 24))
        icon.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        icon.contentTintColor = Colors.accent
        container.addSubview(icon)
        self.iconView = icon
        
        let title = makeLabel(
            frame: NSRect(x: Layout.padding + 32, y: y - 22, width: Layout.width - 60, height: 20),
            text: "Copying...",
            font: .systemFont(ofSize: 14, weight: .semibold),
            color: Colors.title
        )
        container.addSubview(title)
        self.titleLabel = title
        y -= 36
        
        // Progress bar
        let progress = NSProgressIndicator(frame: NSRect(
            x: Layout.padding,
            y: y - 16,
            width: Layout.width - Layout.padding * 2 - 50,
            height: 16
        ))
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 100
        progress.doubleValue = 0
        container.addSubview(progress)
        self.progressBar = progress
        
        let percent = makeLabel(
            frame: NSRect(x: Layout.width - Layout.padding - 45, y: y - 14, width: 45, height: 16),
            text: "0%",
            font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            color: Colors.primary
        )
        container.addSubview(percent)
        self.percentLabel = percent
        y -= 28
        
        // Current file
        let currentFile = makeLabel(
            frame: NSRect(x: Layout.padding, y: y - 14, width: Layout.width - Layout.padding * 2, height: 14),
            text: "",
            font: .systemFont(ofSize: 11),
            color: Colors.secondary
        )
        currentFile.lineBreakMode = .byTruncatingMiddle
        container.addSubview(currentFile)
        self.currentFileLabel = currentFile
        y -= 22
        
        // Stats row
        let stats = makeLabel(
            frame: NSRect(x: Layout.padding, y: y - 14, width: Layout.width - Layout.padding * 2, height: 14),
            text: "Transferred: 0 B / 0 B",
            font: .systemFont(ofSize: 11),
            color: Colors.secondary
        )
        container.addSubview(stats)
        self.statsLabel = stats
        y -= 18
        
        // Speed & ETA row
        let speed = makeLabel(
            frame: NSRect(x: Layout.padding, y: y - 14, width: 150, height: 14),
            text: "Speed: —",
            font: .monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            color: Colors.secondary
        )
        container.addSubview(speed)
        self.speedLabel = speed
        
        let eta = makeLabel(
            frame: NSRect(x: Layout.padding + 160, y: y - 14, width: 150, height: 14),
            text: "Remaining: —",
            font: .systemFont(ofSize: 11),
            color: Colors.secondary
        )
        container.addSubview(eta)
        self.etaLabel = eta
        y -= 22
        
        // Error label (hidden by default)
        let errorLbl = makeLabel(
            frame: NSRect(x: Layout.padding, y: y - 14, width: 200, height: 14),
            text: "",
            font: .systemFont(ofSize: 11, weight: .medium),
            color: Colors.error
        )
        errorLbl.isHidden = true
        container.addSubview(errorLbl)
        self.errorLabel = errorLbl
        
        // Buttons
        let btnWidth: CGFloat = 80
        let btnHeight: CGFloat = 24
        let btnY: CGFloat = Layout.padding
        
        let cancelBtn = NSButton(frame: NSRect(
            x: Layout.width - Layout.padding - btnWidth,
            y: btnY,
            width: btnWidth,
            height: btnHeight
        ))
        cancelBtn.title = "Cancel"
        cancelBtn.bezelStyle = .rounded
        cancelBtn.target = self
        cancelBtn.action = #selector(cancelTapped)
        container.addSubview(cancelBtn)
        self.cancelButton = cancelBtn
        
        let pauseBtn = NSButton(frame: NSRect(
            x: Layout.width - Layout.padding - btnWidth * 2 - 8,
            y: btnY,
            width: btnWidth,
            height: btnHeight
        ))
        pauseBtn.title = "Pause"
        pauseBtn.bezelStyle = .rounded
        pauseBtn.target = self
        pauseBtn.action = #selector(pauseTapped)
        container.addSubview(pauseBtn)
        self.pauseButton = pauseBtn
        
        self.panel = p
    }
    
    private func makeLabel(frame: NSRect, text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.font = font
        label.textColor = color
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .left
        return label
    }
    
    // MARK: - Actions
    
    @objc private func pauseTapped() {
        onPause?()
    }
    
    @objc private func cancelTapped() {
        onCancel?()
    }
}
