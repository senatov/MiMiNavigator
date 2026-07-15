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
        let item = NSStatusBar.system.statusItem(withLength: 30)
        guard let button = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            log.error("[MenuBar] status item button unavailable")
            return
        }
        let image = NSApp.applicationIconImage.copy() as? NSImage
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false
        button.image = image
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.toolTip = "MiMiNavigator"
        button.setAccessibilityLabel("MiMiNavigator")
        item.menu = makeMenu()
        item.isVisible = true
        statusItem = item
        log.info("[MenuBar] status item installed image=\(image != nil) visible=\(item.isVisible)")
        DispatchQueue.main.async { [weak self] in
            self?.logStatusItemState()
        }
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

    // MARK: - Log State
    private func logStatusItemState() {
        guard let item = statusItem, let button = item.button else {
            log.error("[MenuBar] status item lost after installation")
            return
        }
        let frame = button.window?.frame ?? .zero
        log.info("[MenuBar] status item ready visible=\(item.isVisible) windowVisible=\(button.window?.isVisible == true) frame=\(NSStringFromRect(frame))")
    }
}
