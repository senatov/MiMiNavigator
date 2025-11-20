//
// AppDelegate.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

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
        log.debug("installing keyDown monitor for Tab/Backtab")
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let appState = self.appState else { return event }
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
                    appState.togglePanel()
                    return nil
                } else {
                    log.debug("intercepted Tab → toggle panel")
                    appState.togglePanel()
                    return nil
                }
            }
            return event
        }
    }

    // MARK: -
    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
