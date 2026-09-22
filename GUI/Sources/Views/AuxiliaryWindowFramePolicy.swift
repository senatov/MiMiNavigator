// AuxiliaryWindowFramePolicy.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keeps restored auxiliary windows inside the current display layout.

import AppKit

// MARK: - Auxiliary Window Frame Policy
@MainActor
enum AuxiliaryWindowFramePolicy {
    private static let fallbackMinimumSize = NSSize(width: 240, height: 160)
    static func restoreOrCenter(
        _ window: NSWindow,
        autosaveName: String,
        designedSize: NSSize,
        relativeTo hostWindow: NSWindow? = NSApp.mainWindow
    ) {
        let restored = window.setFrameUsingName(autosaveName)
        if !restored {
            let hostFrame = hostWindow?.frame ?? preferredScreen(for: hostWindow)?.visibleFrame
            let origin = hostFrame.map {
                NSPoint(x: $0.midX - designedSize.width / 2, y: $0.midY - designedSize.height / 2)
            } ?? .zero
            window.setFrame(NSRect(origin: origin, size: designedSize), display: true)
        }
        ensureVisible(window, preferredScreen: preferredScreen(for: hostWindow))
        window.setFrameAutosaveName(autosaveName)
    }

    static func ensureVisible(_ window: NSWindow, preferredScreen: NSScreen? = nil) {
        guard !NSScreen.screens.isEmpty else { return }
        let original = window.frame
        let targetScreen = screen(for: original, preferredScreen: preferredScreen)
        let visible = targetScreen.visibleFrame
        let validFrame = original.origin.x.isFinite && original.origin.y.isFinite
            && original.width.isFinite && original.height.isFinite
            && original.width > 0 && original.height > 0
        let minimumWidth = max(window.minSize.width, fallbackMinimumSize.width)
        let minimumHeight = max(window.minSize.height, fallbackMinimumSize.height)
        let requestedSize = validFrame ? original.size : NSSize(width: minimumWidth, height: minimumHeight)
        let width = min(max(requestedSize.width, min(minimumWidth, visible.width)), visible.width)
        let height = min(max(requestedSize.height, min(minimumHeight, visible.height)), visible.height)
        let x: CGFloat
        let y: CGFloat
        if validFrame {
            x = min(max(original.minX, visible.minX), visible.maxX - width)
            y = min(max(original.minY, visible.minY), visible.maxY - height)
        } else {
            x = visible.midX - width / 2
            y = visible.midY - height / 2
        }
        let corrected = NSRect(x: x, y: y, width: width, height: height)
        guard corrected != original else { return }
        window.setFrame(corrected, display: true)
        log.info("[WindowFrame] corrected auxiliary window '\(window.title)' from \(NSStringFromRect(original)) to \(NSStringFromRect(corrected))")
    }

    private static func screen(for frame: NSRect, preferredScreen: NSScreen?) -> NSScreen {
        if frame.origin.x.isFinite, frame.origin.y.isFinite, frame.width.isFinite, frame.height.isFinite {
            let best = NSScreen.screens.max { first, second in
                intersectionArea(frame, first.visibleFrame) < intersectionArea(frame, second.visibleFrame)
            }
            if let best, intersectionArea(frame, best.visibleFrame) > 0 { return best }
        }
        return preferredScreen ?? NSApp.mainWindow?.screen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static func preferredScreen(for hostWindow: NSWindow?) -> NSScreen? {
        hostWindow?.screen ?? NSApp.mainWindow?.screen ?? NSScreen.main
    }

    private static func intersectionArea(_ first: NSRect, _ second: NSRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}
