// ToolbarRightClickHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Right-click handler for the toolbar area.
//   Strategy: NSEvent local monitor on .rightMouseDown.
//   Checks if the click landed inside the toolbar rect of the main window.
//   If yes → open ToolbarCustomizeCoordinator.
//   This avoids fragile view-hierarchy traversal entirely.

import AppKit

// MARK: - Toolbar Right Click Monitor
@MainActor
final class ToolbarRightClickMonitor {

    static let shared = ToolbarRightClickMonitor()
    private var monitor: Any?

    private init() {}

    // MARK: - Start / Stop

    func start() {
        guard monitor == nil else { return }

        // Local monitor catches events in our own app windows
        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            self?.handleRightClick(event)
            return event  // always pass the event through
        }
        log.debug("[ToolbarRightClick] local monitor started")
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
            log.debug("[ToolbarRightClick] local monitor stopped")
        }
    }

    // MARK: - Hit test

    private func handleRightClick(_ event: NSEvent) {
        guard
            let window = event.window ?? NSApp.mainWindow,
            isInToolbarArea(event: event, window: window)
        else { return }

        log.debug("[ToolbarRightClick] right-click in toolbar area → opening customize panel")
        ToolbarCustomizeCoordinator.shared.toggle()
    }

    /// Returns true if the event location is inside the toolbar area of the window.
    private func isInToolbarArea(event: NSEvent, window: NSWindow) -> Bool {
        // Convert click location to window coordinates
        let locationInWindow = event.locationInWindow

        // Toolbar occupies the strip between top of content area and top of window
        guard let contentView = window.contentView else { return false }

        let contentFrameInWindow = contentView.convert(contentView.bounds, to: nil)
        let windowHeight = window.frame.height

        // Click is above the content view → it's in the toolbar or title bar
        let isAboveContent = locationInWindow.y > contentFrameInWindow.maxY

        // Click is below the top of the window (exclude pure title bar on non-unified toolbars)
        // For unifiedCompact style the toolbar and title bar are merged — any click above content
        // is considered a toolbar click.
        let isInWindow = locationInWindow.y < windowHeight

        let result = isAboveContent && isInWindow
        if result {
            log.debug("[ToolbarRightClick] hit: y=\(Int(locationInWindow.y)) contentMaxY=\(Int(contentFrameInWindow.maxY))")
        }
        return result
    }
}
