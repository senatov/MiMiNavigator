// NetworkNeighborhoodCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Network Neighborhood as standalone NSPanel (same behavior as FindFiles).
//   - Movable, resizable, persists position/size
//   - Does not close when main window loses focus
//   - Rises to front when main window is clicked
//   - Stays on screen as utility panel

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
                self?.onNavigate?(url)
                self?.close()
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
        panel.hidesOnDeactivate = false   // stays visible when clicking main window
        panel.level = .floating
        panel.tabbingMode = .disallowed
        panel.isFloatingPanel = true

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
