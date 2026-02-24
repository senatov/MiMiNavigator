// ToolbarRightClickHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Right-click handler for the toolbar area.
//   Uses NSEvent local monitor on .rightMouseDown.
//   Hit-test: click is above contentView.maxY in window coordinates → toolbar zone.
//   Started in AppDelegate.applicationDidFinishLaunching (guaranteed early init).

import AppKit

// MARK: - Toolbar Right Click Monitor
@MainActor
final class ToolbarRightClickMonitor {

    static let shared = ToolbarRightClickMonitor()
    private var monitor: Any?

    private init() {}

    // MARK: - Start
    func start() {
        guard monitor == nil else {
            log.debug("[ToolbarRightClick] already running — skip")
            return
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            self?.handleRightClick(event)
            return event   // always pass through so system context menus still work
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
        // Find the window — prefer event.window, fall back to key window, then main window
        guard let window = event.window
                        ?? NSApp.keyWindow
                        ?? NSApp.mainWindow else {
            log.debug("[ToolbarRightClick] no window — ignored")
            return
        }

        let loc = event.locationInWindow

        guard let contentView = window.contentView else {
            log.debug("[ToolbarRightClick] no contentView — ignored")
            return
        }

        // contentView origin in window coords (for unifiedCompact toolbar
        // the content view starts below the toolbar strip)
        let contentMinY = contentView.frame.minY
        let contentMaxY = contentView.frame.maxY
        let windowH     = window.frame.height

        log.debug("[ToolbarRightClick] click y=\(Int(loc.y)) contentMinY=\(Int(contentMinY)) contentMaxY=\(Int(contentMaxY)) windowH=\(Int(windowH))")

        // Click is above the content area top edge → title bar / toolbar zone
        // For unifiedCompact this is the only strip above content
        let inToolbarZone = loc.y > contentMaxY && loc.y <= windowH

        guard inToolbarZone else {
            log.debug("[ToolbarRightClick] outside toolbar zone — ignored")
            return
        }

        log.info("[ToolbarRightClick] ✓ right-click in toolbar zone → opening customize panel")
        ToolbarCustomizeCoordinator.shared.toggle()
    }
}
