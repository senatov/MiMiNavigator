// AppDelegate.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.10.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: NSApplicationDelegate. Handles Tab key interception, bookmark restore,
//   and companion panel visibility (Network Neighborhood, Find Files).
//   applicationDidBecomeActive raises companion panels only when MiMiNavigator
//   itself gets focus — not when other apps become active.
//
// Termination strategy:
//   applicationShouldTerminate returns .terminateLater, fires async cleanup,
//   then calls reply(.now) — guarantees the app exits in < 1 s with no spinner.

import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {

    weak var appState: AppState?
    private var keyMonitor: Any?
    private let tabKeyCode: UInt16 = 48

    // MARK: - Bind

    func bind(_ appState: AppState) {
        self.appState = appState
    }

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.debug("restoring security-scoped bookmarks")
        Task {
            let restored = await BookmarkStore.shared.restoreAll()
            log.info("Restored \(restored.count) bookmarks")
        }
        log.debug("starting toolbar right-click monitor")
        ToolbarRightClickMonitor.shared.start()
        log.debug("installing keyDown monitor for Tab/Backtab")
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let appState = self.appState else { return event }
            if ContextMenuCoordinator.shared.activeDialog != nil { return event }
            let flags = event.modifierFlags
            guard !flags.contains(.command), !flags.contains(.option), !flags.contains(.control) else {
                return event
            }
            let isTab = event.keyCode == tabKeyCode || event.charactersIgnoringModifiers == "\t"
            if isTab {
                if flags.contains(.shift) {
                    log.debug("intercepted Shift+Tab → toggle panel")
                } else {
                    log.debug("intercepted Tab → toggle panel")
                }
                appState.toggleFocus()
                return nil
            }
            return event
        }
    }

    // MARK: - Focus

    func applicationDidBecomeActive(_ notification: Notification) {
        NetworkNeighborhoodCoordinator.shared.bringToFront()
        ConnectToServerCoordinator.shared.bringToFront()
        FindFilesCoordinator.shared.bringToFront()
        SettingsCoordinator.shared.bringToFront()
    }

    // MARK: - Termination — fast, no spinner

    /// Returns .terminateLater so we can do async cleanup before exit.
    /// All work must complete and call reply(.now) within the OS timeout (~5 s).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        log.info("[AppDelegate] applicationShouldTerminate — starting async cleanup")
        Task {
            await performCleanupBeforeExit()
            log.info("[AppDelegate] cleanup done — replying .now")
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    /// Synchronously saves state + stops watchers, then resolves async resources.
    /// Must finish in well under 5 s to avoid macOS force-killing the process.
    private func performCleanupBeforeExit() async {
        // 1. Save panel state and cache — synchronous, fast
        appState?.saveBeforeExit()
        // 2. Stop scanner timers and FSEvents streams — synchronous actor work
        if let scanner = appState?.scanner {
            await scanner.stopMonitoring()
        }
        // 3. Stop SpinnerWatchdog poll timer
        SpinnerWatchdog.shared.stop()
        // 4. Cleanup extracted archive temp dirs — actor hop, fast
        await ArchiveManager.shared.cleanup()
        // 5. Release security-scoped bookmarks — actor hop, fast
        await BookmarkStore.shared.stopAll()
        log.info("[AppDelegate] performCleanupBeforeExit complete")
    }

    // MARK: - applicationWillTerminate — key monitor cleanup only

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
