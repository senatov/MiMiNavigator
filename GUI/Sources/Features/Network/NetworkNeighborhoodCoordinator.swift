// NetworkNeighborhoodCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.02.2026.
// Refactored: 23.02.2026 — level=.normal (was .floating); bringToFront moved to AppDelegate
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Network Neighborhood as standalone NSPanel.
//   - level=.floating + hidesOnDeactivate=true: hides when app deactivates, rises when active
//   - Rises to front via AppDelegate.applicationDidBecomeActive (only when MiMi is active)
//   - Movable, resizable, persists position via frameAutosaveName
//   - close() only for file:// URLs; smb:// stays open until mount completes

import AppKit
import SwiftUI

// MARK: - NetworkNeighborhoodCoordinator
@MainActor
@Observable
final class NetworkNeighborhoodCoordinator {

    static let shared = NetworkNeighborhoodCoordinator()

    private(set) var isVisible = false
    private var window: NSPanel?

    private let frameAutosaveName = "MiMiNavigator.NetworkNeighborhoodWindow"
    private let defaultWidth: CGFloat  = 500
    private let defaultHeight: CGFloat = 620

    var onNavigate: ((URL) -> Void)?

    private init() {}

    // MARK: - Toggle
    func toggle() {
        isVisible ? close() : open()
    }

    // MARK: - Open
    func open() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            isVisible = true
            return
        }

        let contentView = NetworkNeighborhoodView(
            onNavigate: { [weak self] url in
                // Close only for file:// URLs (already mounted / local path)
                // For smb:// etc. — App.swift handles mount async, closes after success
                self?.onNavigate?(url)
                if url.isFileURL { self?.close() }
            },
            onDismiss: { [weak self] in self?.close() }
        )
        .frame(minWidth: 380, minHeight: 400)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [
                .titled, .closable, .resizable, .miniaturizable,
                .utilityWindow, .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )
        panel.title = "Network Neighborhood"
        panel.contentView = NSHostingView(rootView: contentView)
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 380, height: 400)
        panel.titlebarAppearsTransparent = false
        panel.titleVisibility = .visible
        panel.toolbarStyle = .unified
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = true
        // Follow main window: hide when app deactivates, rise when app activates
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.tabbingMode = .disallowed

        if !panel.setFrameUsingName(frameAutosaveName) {
            panel.setFrame(computeDefaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(frameAutosaveName)

        panel.delegate = NetworkWindowDelegate.shared
        panel.makeKeyAndOrderFront(nil)

        window = panel
        isVisible = true
        log.info("[Network] panel opened")
    }

    // MARK: - Close
    func close() {
        window?.close()
        isVisible = false
        log.info("[Network] panel closed")
    }

    // MARK: - Called by delegate
    func windowDidClose() {
        isVisible = false
    }

    // MARK: - Raise to front (called when main window becomes key)
    func bringToFront() {
        guard isVisible else { return }
        window?.orderFront(nil)
    }

    // MARK: - Default frame: right of main window
    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)
        if let main = NSApp.mainWindow {
            let mf = main.frame
            let screen = main.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            var x = mf.maxX + 12
            let y = mf.midY - size.height / 2
            if x + size.width > screen.maxX { x = mf.minX - size.width - 12 }
            if x < screen.minX { x = mf.maxX - size.width * 0.3 }
            let cy = max(screen.minY, min(y, screen.maxY - size.height))
            return NSRect(origin: NSPoint(x: x, y: cy), size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(origin: NSPoint(x: sf.midX - size.width/2, y: sf.midY - size.height/2), size: size)
        }
        return NSRect(origin: .zero, size: size)
    }
}

// MARK: - NSWindowDelegate
private final class NetworkWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = NetworkWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            NetworkNeighborhoodCoordinator.shared.windowDidClose()
        }
    }
}
