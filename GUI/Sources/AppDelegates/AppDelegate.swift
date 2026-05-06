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
import LogKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {

    weak var appState: AppState?
    private var keyMonitor: Any?
    private let tabKeyCode: UInt16 = 48
    private let startupDate = CFAbsoluteTimeGetCurrent()
    private var didLogStartupCompletion = false
    private var isTerminationCleanupRunning = false
    private let terminationSaveDebounceInterval: TimeInterval = 1.0

    private func logStartupStep(_ message: String) {
        let elapsed = CFAbsoluteTimeGetCurrent() - startupDate
        let threadLabel = Thread.isMainThread ? "main" : "background"
        log.info("[StartupTrace] +\(String(format: "%.3f", elapsed))s [\(threadLabel)] \(message)")
    }

    // MARK: - Bind

    func bind(_ appState: AppState) {
        self.appState = appState
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logStartupStep("applicationDidFinishLaunching begin")

        // Ensure app is a regular Dock citizen from the very start
        NSApp.setActivationPolicy(.regular)

        UserPreferences.shared.load()
        log.debug("prefs loaded, autoFit=\(UserPreferences.shared.snapshot.autoFitColumnsOnNavigate)")
        logStartupStep("UserPreferences loaded")

        log.debug("restoring security-scoped bookmarks")
        scheduleBookmarkRestore()
        logStartupStep("bookmark restore scheduled")

        log.debug("starting toolbar right-click monitor")
        ToolbarRightClickMonitor.shared.start()
        logStartupStep("toolbar right-click monitor started")

        log.debug("installing keyDown monitor for Tab/Backtab")
        installKeyMonitor()
        logStartupStep("key monitor installed")

        installMainWindowObserver()
        logStartupStep("main window observer installed")

        scheduleAutoConnectServers()
        logStartupStep("auto-connect scheduled")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.logStartupCompletionIfNeeded(reason: "next main-turn after applicationDidFinishLaunching")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.logStartupCompletionIfNeeded(reason: "1.0s delayed checkpoint")
        }
    }

    private func scheduleAutoConnectServers() {
        Task(priority: .utility) { [weak self] in
            self?.logStartupStep("auto-connect servers begin")
            await RemoteConnectionManager.shared.connectOnStartIfNeeded()
            self?.logStartupStep("auto-connect servers done")
        }
    }


    private func scheduleBookmarkRestore() {
        Task(priority: .utility) { [weak self] in
            self?.logStartupStep("bookmark restore task begin")

            // Restore all persisted bookmarks (no popup — uses saved data only).
            let restored = await BookmarkStore.shared.restoreAll()
            self?.logStartupStep("restoreAll finished count=\(restored.count)")
            log.info("Restored \(restored.count) bookmarks")
        }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let appState = self.appState else { return event }
            if CntMenuCoord.shared.activeDialog != nil { return event }
            let flags = event.modifierFlags
            guard !flags.contains(.command), !flags.contains(.option), !flags.contains(.control) else {
                return event
            }
            let isTab = event.keyCode == self.tabKeyCode || event.charactersIgnoringModifiers == "\t"
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

    private func installMainWindowObserver() {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc private func handleWindowDidBecomeKey(_ notification: Notification) {
        guard !isTerminationCleanupRunning, appState?.isTerminating != true else { return }
        guard let window = notification.object as? NSWindow else { return }
        guard window == NSApp.mainWindow else { return }
        bringAuxiliaryPanelsToFront()
    }

    private func logStartupCompletionIfNeeded(reason: String) {
        guard !didLogStartupCompletion else { return }
        didLogStartupCompletion = true
        logStartupStep("startup checkpoint reached: \(reason)")
    }

    // MARK: - Focus

    func applicationDidBecomeActive(_ notification: Notification) {
        if isTerminationCleanupRunning || appState?.isTerminating == true {
            log.info("[AppDelegate] applicationDidBecomeActive ignored — app is terminating")
            return
        }

        bringAuxiliaryPanelsToFront()
    }

    private func bringAuxiliaryPanelsToFront() {
        NetworkNeighborhoodCoordinator.shared.bringToFront()
        PackDialogCoordinator.shared.bringToFront()
        ConnectToServerCoordinator.shared.bringToFront()
        FindFilesCoordinator.shared.bringToFront()
        SettingsCoordinator.shared.bringToFront()
        ToolbarCustomizeCoordinator.shared.bringToFront()
        MediaInfoPanel.shared.bringToFront()
    }

    // MARK: - Termination — fast, no spinner

    /// Returns .terminateLater so we can do async cleanup before exit.
    /// All work must complete and call reply(.now) within the OS timeout (~5 s).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isTerminationCleanupRunning {
            log.info("[AppDelegate] applicationShouldTerminate — cleanup already running")
            return .terminateLater
        }

        isTerminationCleanupRunning = true
        appState?.beginTermination()
        NSApp.deactivate()
        log.info("[AppDelegate] applicationShouldTerminate — starting async cleanup")

        Task { [weak self] in
            guard let self else {
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
                return
            }

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
        if shouldSkipTerminationStateSave() {
            log.info("[AppDelegate] performCleanupBeforeExit — skipping duplicate saveBeforeExit")
        } else {
            appState?.saveBeforeExit()
        }
        // 2. Stop scanner timers and FSEvents streams — synchronous actor work
        await DirectorySizeService.shared.shutdown()
        if let scanner = appState?.scanner {
            await scanner.stopMonitoring()
        }
        // 3. Stop SpinnerWatchdog poll timer
        SpinnerWatchdog.shared.stop()
        // 4. Cleanup extracted archive temp dirs — actor hop, fast
        await ArchiveManager.shared.cleanup()
        // 5. Release security-scoped bookmarks — actor hop, fast
        await BookmarkStore.shared.stopAll()
        // 6. Flush file loggers before the process exits so /tmp mirror is complete
        LogKit.flush(timeoutSeconds: 2)
        log.info("[AppDelegate] performCleanupBeforeExit complete")
    }

    private func shouldSkipTerminationStateSave() -> Bool {
        let urls = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mimi/state.json"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mimi/panel_startup_cache.json")
        ]

        let now = Date()
        let recentlySaved = urls.contains { url in
            guard let modificationDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date else {
                return false
            }

            return now.timeIntervalSince(modificationDate) <= terminationSaveDebounceInterval
        }

        if recentlySaved {
            log.debug("[AppDelegate] recent state file modification detected — debounce active")
        }

        return recentlySaved
    }

    // MARK: - applicationWillTerminate — key monitor cleanup only

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
    }
}
