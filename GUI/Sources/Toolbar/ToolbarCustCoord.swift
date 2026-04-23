// ToolbarCustCoord.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Toolbar Customize as standalone NSPanel.
//   Same pattern as SettingsCoordinator — proper NSWindowDelegate, frame autosave.

import AppKit
import SwiftUI

// MARK: - Toolbar Customize Coordinator
@MainActor
@Observable
final class ToolbarCustomizeCoordinator {

    static let shared = ToolbarCustomizeCoordinator()

    private(set) var isVisible = false
    private var window: NSPanel?

    private let frameAutosaveName = "MiMiNavigator.ToolbarCustomizePanel"
    private let defaultWidth: CGFloat = 520
    private let defaultHeight: CGFloat = 560

    private init() {}


    func toggle() {
        isVisible ? close() : show()
    }


    func show() {
        log.debug("[ToolbarCustomize] show() invoked")
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            isVisible = true
            return
        }
        let contentView = ToolbarCustomizeRootView(onDismiss: { [weak self] in self?.close() })
            .frame(minWidth: 440, minHeight: 460)
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: contentView)
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 440, height: 460)
        panel.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(to: panel, systemImage: "wrench.adjustable", title: "Customize Toolbar")
        panel.toolbarStyle = .unified
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .normal
        panel.tabbingMode = .disallowed
        panel.hasShadow = true
        panel.backgroundColor = NSColor(DialogColors.base)
        if !panel.setFrameUsingName(frameAutosaveName) {
            panel.setFrame(computeDefaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(frameAutosaveName)
        panel.delegate = ToolbarCustWindowDelegate.shared
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        self.window = panel
        isVisible = true
        log.info("[ToolbarCustomize] opened ✓")
    }


    func close() {
        log.debug("[ToolbarCustomize] close() invoked")
        window?.close()
        isVisible = false
        log.info("[ToolbarCustomize] closed ✓")
    }


    func windowDidClose() {
        isVisible = false
    }


    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)
        if let main = NSApp.mainWindow {
            let mf = main.frame
            return NSRect(origin: NSPoint(x: mf.midX - size.width / 2, y: mf.midY - size.height / 2), size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(origin: NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2), size: size)
        }
        return NSRect(origin: .zero, size: size)
    }
}


// MARK: - NSWindowDelegate
private final class ToolbarCustWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = ToolbarCustWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            ToolbarCustomizeCoordinator.shared.windowDidClose()
        }
    }
}
