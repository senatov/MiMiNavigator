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
    private let toolbarHeight: CGFloat = 52
    private let duplicateClickSuppressionInterval: TimeInterval = 0.5
    private var lastOpenAttemptAt: TimeInterval = 0
    private init() {}

    // MARK: - Start / Stop

    func start() {
        guard monitor == nil else {
            log.debug("[ToolbarRightClick] already running — skip")
            return
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            self?.handleRightClick(event) ?? event
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
    private func handleRightClick(_ event: NSEvent) -> NSEvent? {
        log.debug("[ToolbarRightClick] event received")

        guard let window = resolveWindow(from: event) else {
            log.debug("[ToolbarRightClick] no window — ignored")
            return event
        }

        if isClickInToolbar(event: event, window: window) {
            log.info("[ToolbarRightClick] ✓ opening customize panel")
            openCustomizePanel()
            return nil
        } else {
            log.debug("[ToolbarRightClick] click outside toolbar — ignored")
            return event
        }
    }

    // MARK: - Helpers
    private func resolveWindow(from event: NSEvent) -> NSWindow? {
        log.debug(#function + " called")
        if let window = event.window {
            return window
        }
        if let window = NSApp.keyWindow {
            return window
        }
        return NSApp.mainWindow
    }

    private func isClickInToolbar(event: NSEvent, window: NSWindow) -> Bool {
        let y = event.locationInWindow.y
        let windowHeight = window.frame.height
        // Coordinates are already in points, no scale needed
        let threshold = windowHeight - toolbarHeight
        let isInside = y >= threshold
        log.debug(
            "[ToolbarRightClick] hitTest y=\(Int(y)) windowH=\(Int(windowHeight)) threshold=\(Int(threshold)) result=\(isInside)"
        )
        return isInside
    }

    private func openCustomizePanel() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastOpenAttemptAt < duplicateClickSuppressionInterval {
            log.debug("[ToolbarRightClick] duplicate click suppressed")
            return
        }
        lastOpenAttemptAt = now
        log.debug("[ToolbarRightClick] scheduling customize panel for next main-turn")
        DispatchQueue.main.async {
            ToolbarCustomizeCoordinator.shared.show()
        }
    }
}
