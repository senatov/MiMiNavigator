//
//  AppDelegate.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit

// Keep app-level event hooks here (keyboard, lifecycle, etc.)
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    private var keyMonitor: Any?
    private let tabKeyCode: UInt16 = 48 // Hardware keyCode for Tab

    func bind(_ appState: AppState) {
        // Keep a weak reference to avoid retain cycles.
        self.appState = appState
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.debug("Installing local keyDown monitor for Tab/Backtab")
        // Intercept Tab / Shift+Tab before the key view loop processes them.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let appState = self.appState else { return event }

            // Ignore if Command/Option/Control are pressed – we only want a plain Tab or Shift+Tab.
            let hasCommand = event.modifierFlags.contains(.command)
            let hasOption = event.modifierFlags.contains(.option)
            let hasControl = event.modifierFlags.contains(.control)
            if hasCommand || hasOption || hasControl {
                return event
            }

            // 48 is the hardware keyCode for Tab. `characters` can be "\t" as well.
            let isTabKeyCode = (event.keyCode == tabKeyCode)
            let charsIgnoringMods = event.charactersIgnoringModifiers
            let isTabChar = (charsIgnoringMods == "\t")

            if isTabKeyCode || isTabChar {
                if event.modifierFlags.contains(.shift) {
                    log.debug("Intercepted Shift+Tab → toggle panel (local monitor)")
                    appState.togglePanel()
                    return nil  // Swallow so system does not traverse focus.
                } else {
                    log.debug("Intercepted Tab → toggle panel (local monitor)")
                    appState.togglePanel()
                    return nil  // Swallow so system does not traverse focus.
                }
            }
            return event
        }
    }

    // NOTE: We remove the local key monitor in applicationWillTerminate to satisfy Swift 6.2 concurrency rules.
    // deinit is nonisolated by default and cannot safely access main-actor isolated, non-Sendable properties like `keyMonitor`.
    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
