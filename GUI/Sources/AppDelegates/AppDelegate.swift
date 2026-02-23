// AppDelegate.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.10.2025.
// Refactored: 23.02.2026 — applicationDidBecomeActive raises Network+FindFiles panels
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: NSApplicationDelegate. Handles Tab key interception, bookmark restore,
//   and companion panel visibility (Network Neighborhood, Find Files).
//   applicationDidBecomeActive raises companion panels only when MiMiNavigator
//   itself gets focus — not when other apps become active.

import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    private var keyMonitor: Any?
    private let tabKeyCode: UInt16 = 48

    // MARK: -
    func bind(_ appState: AppState) {
        self.appState = appState
    }

    // MARK: -
    func applicationDidFinishLaunching(_ notification: Notification) {
        log.debug("restoring security-scoped bookmarks")
        Task {
            let restored = await BookmarkStore.shared.restoreAll()
            log.info("Restored \(restored.count) bookmarks")
        }
        
        log.debug("installing keyDown monitor for Tab/Backtab")
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let appState = self.appState else { return event }
            // When a modal dialog is active, let SwiftUI handle all keys
            if ContextMenuCoordinator.shared.activeDialog != nil {
                return event
            }
            let hasCommand = event.modifierFlags.contains(.command)
            let hasOption = event.modifierFlags.contains(.option)
            let hasControl = event.modifierFlags.contains(.control)
            if hasCommand || hasOption || hasControl {
                return event
            }
            let isTabKeyCode = (event.keyCode == tabKeyCode)
            let charsIgnoringMods = event.charactersIgnoringModifiers
            let isTabChar = (charsIgnoringMods == "\t")
            if isTabKeyCode || isTabChar {
                if event.modifierFlags.contains(.shift) {
                    log.debug("intercepted Shift+Tab → toggle panel")
                    appState.toggleFocus()
                    return nil
                } else {
                    log.debug("intercepted Tab → toggle panel")
                    appState.toggleFocus()
                    return nil
                }
            }
            return event
        }
    }

    // MARK: - Raise companion panels when MiMiNavigator itself becomes active
    // Triggered only when our app gets focus (user clicks MiMi or switches via Cmd+Tab)
    // NOT triggered when other apps become active — so panel never floats over them
    func applicationDidBecomeActive(_ notification: Notification) {
        NetworkNeighborhoodCoordinator.shared.bringToFront()
        ConnectToServerCoordinator.shared.bringToFront()
        FindFilesCoordinator.shared.bringToFront()
    }

    // MARK: -
    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        
        // Stop all security-scoped resource access
        Task {
            await BookmarkStore.shared.stopAll()
        }
    }
}
