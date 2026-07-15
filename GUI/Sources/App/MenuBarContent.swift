// MenuBarContent.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent menu bar commands for reopening and controlling the app.

import AppKit
import SwiftUI

// MARK: - Menu Bar Content
struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    // MARK: - Body
    var body: some View {
        Button("Show MiMiNavigator") { showMainWindow() }
        Button("Settings…") { showSettings() }
        Divider()
        Button("Quit MiMiNavigator") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    // MARK: - Show Main Window
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = existingMainWindow {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        log.info("[MenuBar] show main window")
    }

    // MARK: - Show Settings
    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        SettingsCoordinator.shared.open()
        log.info("[MenuBar] show settings")
    }

    private var existingMainWindow: NSWindow? {
        NSApp.windows.first {
            !($0 is NSPanel) && $0.styleMask.contains(.titled) && $0.canBecomeMain
        }
    }
}
