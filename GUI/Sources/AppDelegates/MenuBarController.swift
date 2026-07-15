// MenuBarController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent AppKit status item for reopening and controlling the app.

import AppKit

// MARK: - Menu Bar Controller
@MainActor final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?

    // MARK: - Install
    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "MiMiNavigator")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "MiMiNavigator"
        item.menu = makeMenu()
        statusItem = item
        log.info("[MenuBar] status item installed")
    }

    // MARK: - Make Menu
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show MiMiNavigator", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MiMiNavigator", action: #selector(quitApplication), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        return menu
    }

    // MARK: - Show Main Window
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = existingMainWindow {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
        }
        log.info("[MenuBar] show main window")
    }

    // MARK: - Show Settings
    @objc private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        SettingsCoordinator.shared.open()
        log.info("[MenuBar] show settings")
    }

    // MARK: - Quit Application
    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    private var existingMainWindow: NSWindow? {
        NSApp.windows.first {
            !($0 is NSPanel) && $0.styleMask.contains(.titled) && $0.canBecomeMain
        }
    }
}
