// AboutCoordinator.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Coordinator for About window — shows app info panel.

import AppKit
import SwiftUI

// MARK: - AboutCoordinator
@MainActor
final class AboutCoordinator {
    static let shared = AboutCoordinator()
    
    private var panel: NSPanel?
    private let frameAutosaveName = "MiMiNavigator.AboutWindow"
    
    private init() {}
    
    func showAbout() {
        // If already open, bring to front
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        
        let aboutView = AboutView()
        let hostingView = NSHostingView(rootView: aboutView)
        
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        p.title = "About MiMiNavigator"
        p.contentView = hostingView
        p.isMovableByWindowBackground = true
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.backgroundColor = .windowBackgroundColor
        p.isFloatingPanel = false
        p.becomesKeyOnlyIfNeeded = false
        p.level = .normal

        // Center on screen or restore position
        if !p.setFrameUsingName(frameAutosaveName) {
            p.center()
        }
        p.setFrameAutosaveName(frameAutosaveName)
        
        // Show
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.panel = p
        
        log.debug("[AboutCoordinator] About panel shown")
    }
    
    func close() {
        panel?.close()
        panel = nil
    }
}

// MARK: - Global helper
@MainActor
func showAboutWindow() {
    AboutCoordinator.shared.showAbout()
}
