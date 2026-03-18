// UpdateCoordinator.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Coordinator for update check window.

import AppKit
import SwiftUI

// MARK: - UpdateCoordinator
@MainActor
final class UpdateCoordinator {
    static let shared = UpdateCoordinator()
    
    private var panel: NSPanel?
    private let frameAutosaveName = "MiMiNavigator.UpdateWindow"
    
    private init() {}
    
    func checkForUpdates() {
        // If already open, bring to front
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        
        let updateView = UpdateView()
        let hostingView = NSHostingView(rootView: updateView)
        
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        p.title = "Software Update"
        p.contentView = hostingView
        p.isMovableByWindowBackground = false
        p.backgroundColor = .windowBackgroundColor
        p.isFloatingPanel = false
        p.level = .normal
        
        if !p.setFrameUsingName(frameAutosaveName) {
            p.center()
        }
        p.setFrameAutosaveName(frameAutosaveName)
        
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.panel = p
        
        // Start checking
        Task {
            await UpdateChecker.shared.checkForUpdates()
        }
        
        log.debug("[UpdateCoordinator] Update panel shown")
    }
    
    func close() {
        panel?.close()
        panel = nil
    }
}

// MARK: - Global helper
@MainActor
func showUpdateWindow() {
    UpdateCoordinator.shared.checkForUpdates()
}
