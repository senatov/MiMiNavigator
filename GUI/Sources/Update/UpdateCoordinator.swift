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
    private var automaticCheckTask: Task<Void, Never>?
    private let frameAutosaveName = "MiMiNavigator.UpdateWindow"
    private let automaticCheckInterval: UInt64 = 86_400_000_000_000
    
    private init() {}

    // MARK: - Automatic Checks
    func startAutomaticChecks() {
        guard automaticCheckTask == nil else { return }
        automaticCheckTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            while !Task.isCancelled {
                await self?.performAutomaticCheck()
                try? await Task.sleep(nanoseconds: self?.automaticCheckInterval ?? 86_400_000_000_000)
            }
        }
        log.info("[UpdateCoordinator] automatic checks scheduled every 24 hours")
    }

    private func performAutomaticCheck() async {
        await UpdateChecker.shared.checkForUpdates()
        guard UpdateChecker.shared.updateAvailable else { return }
        showPanel(startCheck: false)
    }
    
    func checkForUpdates() {
        log.debug(#function + "()")
        showPanel(startCheck: true)
    }

    private func showPanel(startCheck: Bool) {
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
        p.hidesOnDeactivate = false
        p.tabbingMode = .disallowed
        if !p.setFrameUsingName(frameAutosaveName) {
            p.center()
        }
        p.setFrameAutosaveName(frameAutosaveName)
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = p
        if startCheck {
            Task {
                await UpdateChecker.shared.checkForUpdates()
            }
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
