// DragDestinationWindowResolver.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.06.2026.
// Description: Verifies that a drag release is visible over a MiMiNavigator window.

import AppKit
import CoreGraphics

// MARK: - Drag Destination Window Resolver
@MainActor
enum DragDestinationWindowResolver {
    // MARK: - Is Window Topmost
    static func isWindowTopmost(_ window: NSWindow, at screenPoint: NSPoint) -> Bool {
        guard window.frame.contains(screenPoint) else { return false }
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else {
            return window.isKeyWindow
        }
        let quartzPoint = quartzScreenPoint(from: screenPoint)
        for info in windowInfo where isRegularVisibleWindow(info) {
            guard let bounds = windowBounds(from: info), bounds.contains(quartzPoint) else { continue }
            return windowNumber(from: info) == window.windowNumber
        }
        return false
    }

    // MARK: - Quartz Screen Point
    private static func quartzScreenPoint(from appKitPoint: NSPoint) -> CGPoint {
        let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
        return CGPoint(
            x: appKitPoint.x,
            y: mainDisplayBounds.height - appKitPoint.y
        )
    }

    // MARK: - Regular Visible Window
    private static func isRegularVisibleWindow(_ info: [CFString: Any]) -> Bool {
        let layer = info[kCGWindowLayer] as? Int ?? -1
        let alpha = info[kCGWindowAlpha] as? Double ?? 0
        return layer == 0 && alpha > 0
    }

    // MARK: - Window Bounds
    private static func windowBounds(from info: [CFString: Any]) -> CGRect? {
        guard let dictionary = info[kCGWindowBounds] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
    }

    // MARK: - Window Number
    private static func windowNumber(from info: [CFString: Any]) -> Int? {
        info[kCGWindowNumber] as? Int
    }
}
