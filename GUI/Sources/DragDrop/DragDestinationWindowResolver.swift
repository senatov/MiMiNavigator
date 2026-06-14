// DragDestinationWindowResolver.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.06.2026.
// Description: Verifies that a drag release is visible over a MiMiNavigator window.

import AppKit

// MARK: - Drag Destination Window Resolver
@MainActor
enum DragDestinationWindowResolver {
    // MARK: - Is Window Topmost
    static func isWindowTopmost(_ window: NSWindow, at screenPoint: NSPoint) -> Bool {
        guard window.frame.contains(screenPoint) else { return false }
        let frontmostWindowNumber = NSWindow.windowNumber(
            at: screenPoint,
            belowWindowWithWindowNumber: 0
        )
        return frontmostWindowNumber == window.windowNumber
    }
}
