// HotKeySettingsCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages the Keyboard Shortcuts settings window as a standalone NSWindow

import AppKit
import SwiftUI

// MARK: - Hot Key Settings Coordinator
/// Opens the Keyboard Shortcuts settings as a separate floating window (non-modal).
@MainActor
final class HotKeySettingsCoordinator {

    static let shared = HotKeySettingsCoordinator()

    private var settingsWindow: NSWindow?

    private init() {}

    // MARK: - Show Settings

    func showSettings() {
        // If window already exists, bring to front
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: HotKeySettingsView())
        hostingView.frame = NSRect(x: 0, y: 0, width: 700, height: 520)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyboard Shortcuts"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("HotKeySettingsWindow")
        window.minSize = NSSize(width: 600, height: 400)

        // Use utility panel style — stays on top but doesn't block main window
        window.level = .floating
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unified

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
        log.info("[HotKeys] Settings window opened")
    }

    // MARK: - Close Settings

    func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
    }
}
