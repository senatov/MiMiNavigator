// ToolbarRightClickHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Right-click handler for the toolbar area.
//   Uses NSEvent local monitor on .rightMouseDown.
//   Log analysis showed: contentView covers entire window (y=0..windowH),
//   so toolbar zone is detected as the top 60pt of the window frame.
//   Started in AppDelegate.applicationDidFinishLaunching.

import AppKit

// MARK: - Toolbar Right Click Monitor
@MainActor
final class ToolbarRightClickMonitor {

    static let shared = ToolbarRightClickMonitor()
    private var monitor: Any?

    private init() {}

    // MARK: - Start / Stop

    func start() {
        guard monitor == nil else {
            log.debug("[ToolbarRightClick] already running — skip")
            return
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            self?.handleRightClick(event)
            return event
        }
        log.info("[ToolbarRightClick] monitor started ✓")
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
            log.info("[ToolbarRightClick] monitor stopped")
        }
    }

    // MARK: - Hit test

    private func handleRightClick(_ event: NSEvent) {
        guard let window = event.window ?? NSApp.keyWindow ?? NSApp.mainWindow else {
            log.debug("[ToolbarRightClick] no window — ignored")
            return
        }

        let y       = event.locationInWindow.y
        let windowH = window.frame.height

        // Log analysis: contentView.maxY == windowH (SwiftUI fills entire window).
        // Toolbar is physically at the TOP of the window.
        // Standard unifiedCompact toolbar = ~52pt; use 60pt margin.
        let toolbarZoneBottom = windowH - 60
        let inToolbar = y >= toolbarZoneBottom

        log.debug("[ToolbarRightClick] click y=\(Int(y)) windowH=\(Int(windowH)) threshold=\(Int(toolbarZoneBottom)) hit=\(inToolbar)")

        guard inToolbar else { return }

        log.info("[ToolbarRightClick] ✓ opening customize panel")
        ToolbarCustomizeCoordinator.shared.toggle()
    }
}
