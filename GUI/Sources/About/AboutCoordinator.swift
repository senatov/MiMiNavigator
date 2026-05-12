// AboutCoordinator.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Coordinator for About window — shows app info panel.

import AppKit
import SwiftUI


// MARK: - AboutCoordinator
@MainActor
final class AboutCoordinator: NSObject, NSWindowDelegate {
    static let shared = AboutCoordinator()

    private var panel: NSPanel?
    private let frameAutosaveName = "MiMiNavigator.AboutWindow"

    private override init() {
        super.init()
    }



    // MARK: - Show
    func showAbout() {
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let p = makePanel()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = p
        log.debug("[AboutCoordinator] panel shown")
    }



    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        panel = nil
        log.debug("[AboutCoordinator] panel closed, ref cleared")
    }



    // MARK: - Build Panel
    private func makePanel() -> NSPanel {
        let aboutView = AboutView(onClose: { [weak self] in
            self?.panel?.close()
        })
        let hostingView = NSHostingView(rootView: aboutView)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = "About MiMiNavigator"
        p.contentView = hostingView
        p.delegate = self
        p.isMovableByWindowBackground = true
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.backgroundColor = .windowBackgroundColor
        p.isFloatingPanel = false
        p.becomesKeyOnlyIfNeeded = false
        p.level = .normal
        p.hidesOnDeactivate = false
        p.tabbingMode = .disallowed

        if !p.setFrameUsingName(frameAutosaveName) {
            p.center()
        }
        p.setFrameAutosaveName(frameAutosaveName)
        return p
    }
}



// MARK: - Global helper
@MainActor
func showAboutWindow() {
    AboutCoordinator.shared.showAbout()
}
