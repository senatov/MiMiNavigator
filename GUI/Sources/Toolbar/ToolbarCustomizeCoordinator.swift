// ToolbarCustomizeCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Floating NSPanel for toolbar customization.
//   - First open: centered on main window (or screen fallback)
//   - User can resize/move; position persisted via frameAutosaveName
//   - Resizable: user can drag edges to resize

import AppKit
import SwiftUI

// MARK: - Toolbar Customize Coordinator
@MainActor
final class ToolbarCustomizeCoordinator {

    static let shared = ToolbarCustomizeCoordinator()
    private var panel: NSPanel?

    private let frameAutosaveName = "MiMiNavigator.ToolbarCustomizePanel"
    private let defaultSize = NSSize(width: 360, height: 490)

    private init() {}

    // MARK: - Toggle
    func toggle() {
        if let p = panel, p.isVisible { close() } else { show() }
    }

    // MARK: - Show
    func show() {
        guard panel == nil || panel?.isVisible == false else { return }

        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        p.title = ""
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = true
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.contentView = NSHostingView(rootView: ToolbarCustomizeView())
        p.hasShadow = true
        p.animationBehavior = .utilityWindow
        p.backgroundColor = NSColor(DialogColors.base)
        p.minSize = NSSize(width: 300, height: 380)

        // Restore saved frame, or default to center of main window
        if !p.setFrameUsingName(frameAutosaveName) {
            p.setFrame(defaultFrame(), display: false)
        }
        p.setFrameAutosaveName(frameAutosaveName)

        p.makeKeyAndOrderFront(nil)
        self.panel = p
        log.info("[ToolbarCustomize] opened")
    }

    // MARK: - Close
    func close() {
        panel?.orderOut(nil)
        panel = nil
        log.info("[ToolbarCustomize] closed")
    }

    // MARK: - Default: centered on main window
    private func defaultFrame() -> NSRect {
        let size = defaultSize
        if let win = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            let mf = win.frame
            let x  = mf.midX - size.width  / 2
            let y  = mf.midY - size.height / 2
            return NSRect(origin: NSPoint(x: x, y: y), size: size)
        }
        // screen fallback
        let sf = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSRect(
            x: sf.midX - size.width  / 2,
            y: sf.midY - size.height / 2,
            width: size.width, height: size.height
        )
    }
}
