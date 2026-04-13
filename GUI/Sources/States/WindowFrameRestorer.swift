// WindowFrameRestorer.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 09.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dedicated post-launch window frame restoration.
//   Runs AFTER the window is fully visible on screen — avoids SwiftUI
//   .defaultSize / .defaultPosition race conditions that plagued earlier
//   attempts at restoring geometry from .onAppear.
//
//   Strategy:
//     1. Poll until a visible non-panel window exists (max ~2s).
//     2. Read saved frame from state.json.
//     3. Apply if valid & on-screen; fallback to sensible defaults otherwise.
//     4. Start tracking resize/move for future saves.

import AppKit

@MainActor
final class WindowFrameRestorer {

    static let shared = WindowFrameRestorer()

    private var didRestore = false

    private static let defaultWidth:  CGFloat = 1200
    private static let defaultHeight: CGFloat = 700
    private static let minWidth:      CGFloat = 600
    private static let minHeight:     CGFloat = 400
    private static let maxPollTicks   = 20      // 20 × 100ms = 2s
    private static let pollInterval   = 0.1     // seconds


    private init() {}


    /// Call once from AppDelegate.applicationDidFinishLaunching or .onAppear —
    /// the actual setFrame is deferred until the window is truly on screen.
    func scheduleRestore() {
        guard !didRestore else { return }
        log.info("[WindowFrameRestorer] scheduled — will poll for visible window")
        Task { @MainActor in
            await pollAndRestore()
        }
    }


    private func pollAndRestore() async {
        var tick = 0
        while tick < Self.maxPollTicks {
            if let win = findMainWindow(), win.isVisible {
                applyFrame(to: win)
                return
            }
            tick += 1
            try? await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
        }
        log.warning("[WindowFrameRestorer] gave up after \(Self.maxPollTicks) ticks — no visible window")
    }


    private func findMainWindow() -> NSWindow? {
        let candidateWindows = NSApp.windows.filter { win in
            !(win is NSPanel) && win.contentView != nil && win.isVisible
        }

        if let mainWindow = candidateWindows.first(where: { $0.isMainWindow }) {
            return mainWindow
        }

        if let keyWindow = candidateWindows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }

        return candidateWindows.first
    }


    private func applyFrame(to win: NSWindow) {
        didRestore = true

        if let savedFrame = StatePersistence.restoreWindowFrame() {
            if isUsable(savedFrame) {
                win.setFrame(savedFrame, display: true, animate: false)
                StatePersistence.lastKnownWindowFrame = savedFrame
                log.info("[WindowFrameRestorer] restored saved frame \(fmtRect(savedFrame))")
                StatePersistence.startTrackingWindowFrame()
                return
            }

            if let adjustedFrame = adjustedFrameIfPossible(savedFrame) {
                win.setFrame(adjustedFrame, display: true, animate: false)
                StatePersistence.lastKnownWindowFrame = adjustedFrame
                log.warning("[WindowFrameRestorer] adjusted unusable saved frame \(fmtRect(savedFrame)) -> \(fmtRect(adjustedFrame))")
                StatePersistence.startTrackingWindowFrame()
                return
            }

            log.warning("[WindowFrameRestorer] saved frame rejected as unusable: \(fmtRect(savedFrame))")
        } else {
            log.info("[WindowFrameRestorer] no saved frame found — using default frame")
        }

        let fallback = centeredDefault()
        win.setFrame(fallback, display: true, animate: false)
        StatePersistence.lastKnownWindowFrame = fallback
        log.info("[WindowFrameRestorer] applied default frame \(fmtRect(fallback))")

        // no setFrameAutosaveName — we own frame persistence via state.json;
        // autosave races with our setFrame and can overwrite it silently
        StatePersistence.startTrackingWindowFrame()
    }

    private func adjustedFrameIfPossible(_ rect: NSRect) -> NSRect? {
        guard let targetScreen = preferredScreen(for: rect) else { return nil }

        let visibleFrame = targetScreen.visibleFrame
        let width = min(max(rect.width, Self.minWidth), visibleFrame.width)
        let height = min(max(rect.height, Self.minHeight), visibleFrame.height)
        let maxX = visibleFrame.maxX - width
        let maxY = visibleFrame.maxY - height
        let originX = min(max(rect.origin.x, visibleFrame.minX), maxX)
        let originY = min(max(rect.origin.y, visibleFrame.minY), maxY)
        let adjusted = NSRect(x: originX, y: originY, width: width, height: height)

        return isUsable(adjusted) ? adjusted : nil
    }

    private func preferredScreen(for rect: NSRect) -> NSScreen? {
        if let intersectingScreen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(rect) }) {
            return intersectingScreen
        }

        if let containingScreen = NSScreen.screens.first(where: { screen in
            let visibleFrame = screen.visibleFrame
            return rect.midX >= visibleFrame.minX && rect.midX <= visibleFrame.maxX
                && rect.midY >= visibleFrame.minY && rect.midY <= visibleFrame.maxY
        }) {
            return containingScreen
        }

        return NSScreen.main ?? NSScreen.screens.first
    }


    /// Frame must be large enough and overlap at least one screen.
    private func isUsable(_ rect: NSRect) -> Bool {
        guard rect.width >= Self.minWidth, rect.height >= Self.minHeight else { return false }
        return NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
    }


    /// Centered on the main screen with default dimensions.
    private func centeredDefault() -> NSRect {
        let screen = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w = min(Self.defaultWidth, screen.width - 40)
        let h = min(Self.defaultHeight, screen.height - 40)
        let x = screen.midX - w / 2
        let y = screen.midY - h / 2
        return NSRect(x: x, y: y, width: w, height: h)
    }


    private func fmtRect(_ r: NSRect) -> String {
        "\(Int(r.width))×\(Int(r.height)) at (\(Int(r.origin.x)),\(Int(r.origin.y)))"
    }
}
