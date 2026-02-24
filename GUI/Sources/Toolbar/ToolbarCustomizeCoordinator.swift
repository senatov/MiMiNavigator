// ToolbarCustomizeCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages the Toolbar Customization floating NSPanel.
//   Opens anchored just below the toolbar of the main window.
//   Triggered by right-click on the toolbar area.

import AppKit
import SwiftUI

// MARK: - Toolbar Customize Coordinator
@MainActor
final class ToolbarCustomizeCoordinator {

    static let shared = ToolbarCustomizeCoordinator()
    private var panel: NSPanel?

    private init() {}

    // MARK: - Toggle
    func toggle() {
        if let p = panel, p.isVisible {
            close()
        } else {
            show()
        }
    }

    // MARK: - Show
    func show() {
        guard panel == nil || panel?.isVisible == false else { return }

        let content = NSHostingView(rootView: ToolbarCustomizeView())

        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .closable],
            backing: .buffered,
            defer: false
        )
        p.title = ""
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = true
        p.isMovableByWindowBackground = false
        p.level = .floating
        p.contentView = content
        p.hasShadow = true
        p.animationBehavior = .utilityWindow
        p.backgroundColor = NSColor(DialogColors.base)

        // Size to fit content
        let size = NSSize(width: 360, height: 490)
        p.setContentSize(size)

        // Position: anchored below toolbar of main window
        positionPanel(p, size: size)

        p.makeKeyAndOrderFront(nil)
        self.panel = p

        log.info("[ToolbarCustomize] panel opened")
    }

    // MARK: - Close
    func close() {
        panel?.orderOut(nil)
        panel = nil
        log.info("[ToolbarCustomize] panel closed")
    }

    // MARK: - Position: top-left of main window content area, just below toolbar
    private func positionPanel(_ panel: NSPanel, size: NSSize) {
        guard let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) else {
            // Fallback: center of screen
            panel.center()
            return
        }

        let mainFrame = mainWindow.frame
        let toolbarHeight: CGFloat = 52  // approximate macOS unified compact toolbar height

        // Attach to top-left of main window, just below toolbar
        let x = mainFrame.minX + 8
        let y = mainFrame.maxY - toolbarHeight - size.height - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
