// ConnectToServerCoordinator.swift
// MiMiNavigator
//
// Created by Claude — 23.02.2026
// Refactored: 23.02.2026 — wired to RemoteConnectionManager
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages "Connect to Server" as standalone NSPanel.
//   Routes connect actions to RemoteConnectionManager (SFTP/FTP/SMB/AFP).
//   level=.floating + hidesOnDeactivate: follows main window.

import AppKit
import SwiftUI

// MARK: - ConnectToServerCoordinator
@MainActor
@Observable
final class ConnectToServerCoordinator {

    static let shared = ConnectToServerCoordinator()

    private(set) var isVisible = false
    private var window: NSPanel?

    private let frameAutosaveName = "MiMiNavigator.ConnectToServerWindow"
    private let defaultWidth: CGFloat  = 640
    private let defaultHeight: CGFloat = 520

    var onConnect: ((URL, String) -> Void)?

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

        let contentView = ConnectToServerView(
            onConnect: { [weak self] url, password in
                self?.handleConnect(url: url, password: password)
            },
            onDismiss: { [weak self] in self?.close() }
        )
        .frame(minWidth: 560, minHeight: 440)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [
                .titled, .closable, .resizable, .miniaturizable,
                .utilityWindow, .nonactivatingPanel,
            ],
            backing: .buffered,
            defer: false
        )
        panel.title = "Connect to Server"
        panel.contentView = NSHostingView(rootView: contentView)
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 560, height: 440)
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

        panel.delegate = ConnectToServerWindowDelegate.shared
        panel.makeKeyAndOrderFront(nil)

        window = panel
        isVisible = true
        log.info("[ConnectToServer] panel opened")
    }

    // MARK: - Close
    func close() {
        window?.close()
        isVisible = false
        log.info("[ConnectToServer] panel closed")
    }

    // MARK: - Called by delegate
    func windowDidClose() {
        isVisible = false
    }

    // MARK: - Raise to front (called by AppDelegate.applicationDidBecomeActive)
    func bringToFront() {
        guard isVisible else { return }
        window?.orderFront(nil)
    }

    // MARK: - Handle connect action from view
    private func handleConnect(url: URL, password: String) {
        onConnect?(url, password)
        // Find matching server and connect via manager
        let store = RemoteServerStore.shared
        guard let server = store.servers.first(where: { $0.connectionURL == url }) else {
            log.warning("[ConnectCoordinator] no matching server for \(url)")
            return
        }
        Task {
            await RemoteConnectionManager.shared.connect(to: server, password: password)
            if RemoteConnectionManager.shared.isConnected {
                close()
            }
        }
    }

    // MARK: - Default frame: left of main window (Network is right)
    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)
        if let main = NSApp.mainWindow {
            let mf = main.frame
            let screen = main.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            // Try left of main window first
            var x = mf.minX - size.width - 12
            let y = mf.midY - size.height / 2
            // If off-screen left, try right
            if x < screen.minX { x = mf.maxX + 12 }
            // If off-screen right, overlap
            if x + size.width > screen.maxX { x = mf.maxX - size.width * 0.3 }
            let cy = max(screen.minY, min(y, screen.maxY - size.height))
            return NSRect(origin: NSPoint(x: x, y: cy), size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(origin: NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2), size: size)
        }
        return NSRect(origin: .zero, size: size)
    }
}

// MARK: - NSWindowDelegate
private final class ConnectToServerWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = ConnectToServerWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            ConnectToServerCoordinator.shared.windowDidClose()
        }
    }
}
