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
    private let defaultSize = NSSize(width: 420, height: 520)

    private init() {}

    // MARK: - Toggle
    func toggle() {
        if let p = panel, p.isVisible { close() } else { show() }
    }

    // MARK: - Show
    func show() {
        log.debug("[ToolbarCustomize] show() invoked")

        guard panel == nil || panel?.isVisible == false else {
            log.debug("[ToolbarCustomize] already visible — skip")
            return
        }

        let p = makePanel()

        restoreOrApplyDefaultFrame(for: p)
        p.setFrameAutosaveName(frameAutosaveName)

        p.makeKeyAndOrderFront(nil)
        self.panel = p

        log.info("[ToolbarCustomize] opened ✓")
    }

    // MARK: - Panel Factory

    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configure(panel: p)
        return p
    }

    private func configure(panel p: NSPanel) {
        log.debug("[ToolbarCustomize] configuring panel")
        p.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(to: p, systemImage: "wrench.adjustable", title: "Customize Toolbar")
        p.isFloatingPanel = false
        p.becomesKeyOnlyIfNeeded = false
        p.isMovableByWindowBackground = true
        p.level = .normal
        p.contentView = NSHostingView(rootView: ToolbarCustomizeView())
        p.hasShadow = true
        p.animationBehavior = .utilityWindow
        p.backgroundColor = NSColor(DialogColors.base)
        p.minSize = NSSize(width: 360, height: 420)
    }

    // MARK: - Frame Management

    private func restoreOrApplyDefaultFrame(for panel: NSPanel) {
        log.debug(#function + "()")
        if panel.setFrameUsingName(frameAutosaveName) {
            log.debug("[ToolbarCustomize] restored frame from autosave")
        } else {
            let df = defaultFrame()
            panel.setFrame(df, display: false)
            log.debug("[ToolbarCustomize] applied default frame: \(df)")
        }
    }

    // MARK: - Close
    func close() {
        log.debug("[ToolbarCustomize] close() invoked")
        guard let p = panel else {
            log.debug("[ToolbarCustomize] no panel — skip")
            return
        }
        p.orderOut(nil)
        panel = nil

        log.info("[ToolbarCustomize] closed ✓")
    }

    // MARK: - Default: centered on main window
    private func defaultFrame() -> NSRect {
        log.debug(#function + "()")
        let size = defaultSize
        if let win = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
            let mf = win.frame
            let x = mf.midX - size.width / 2
            let y = mf.midY - size.height / 2
            let rect = NSRect(origin: NSPoint(x: x, y: y), size: size)
            log.debug("[ToolbarCustomize] default frame from window: \(rect)")
            return rect
        }
        let sf = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let rect = NSRect(
            x: sf.midX - size.width / 2,
            y: sf.midY - size.height / 2,
            width: size.width, height: size.height
        )
        log.debug("[ToolbarCustomize] default frame from screen fallback: \(rect)")
        return rect
    }
}
