// ConnectToServerCoordinator.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages "Connect to Server" as standalone NSPanel.
//   Routes connect actions to RemoteConnectionManager (SFTP/FTP/SMB/AFP).
//   hidesOnDeactivate=false: stays visible when app loses focus.

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
    private let minWidth: CGFloat = 660
    private let minHeight: CGFloat = 440
    private let panelTitle = "Connect to Server"

    var onConnect: ((URL, String) -> Void)?
    var onDisconnect: (() -> Void)?

    private init() {}

    private var minimumPanelSize: NSSize {
        NSSize(width: minWidth, height: minHeight)
    }

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
            onDisconnect: { [weak self] in
                self?.onDisconnect?()
            },
            onDismiss: { [weak self] in self?.close() }
        )
        .frame(minWidth: minWidth, minHeight: minHeight)

        let panel = makePanel()
        panel.contentView = NSHostingView(rootView: contentView)
        panel.isReleasedWhenClosed = false
        panel.minSize = minimumPanelSize
        panel.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(to: panel, systemImage: "link", title: panelTitle)
        panel.toolbarStyle = .unified
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = false
        // Normal window level — not floating, not always-on-top
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.tabbingMode = .disallowed

        if !panel.setFrameUsingName(frameAutosaveName) {
            panel.setFrame(computeDefaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(frameAutosaveName)

        panel.delegate = ConnectToServerWindowDelegate.shared
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)

        window = panel
        isVisible = true
        log.info("[ConnectToServer] panel opened")
    }

    private func makePanel() -> NSPanel {
        NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
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
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Handle connect action from view
    /// View already called RemoteConnectionManager.connect() for SFTP/FTP.
    /// This just forwards to MiMiNavigatorApp callback for panel path integration.
    /// Panel stays open — user closes it manually.
    private func handleConnect(url: URL, password: String) {
        let scheme = url.scheme ?? ""
        let host = url.host ?? ""
        log.info("[ConnectCoordinator] handleConnect \(scheme)://\(host)")
        onConnect?(url, password)
    }

    // MARK: - Default frame: centered over main window
    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)
        if let main = NSApp.mainWindow {
            let mf = main.frame
            let x = mf.midX - size.width / 2
            let y = mf.midY - size.height / 2
            return NSRect(origin: NSPoint(x: x, y: y), size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(origin: NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2), size: size)
        }
        return NSRect(origin: .zero, size: size)
    }
}

// MARK: - Window Delegate
private final class ConnectToServerWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = ConnectToServerWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            ConnectToServerCoordinator.shared.windowDidClose()
        }
    }
}
