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
import FileModelKit
import LogKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {

    weak var appState: AppState?
    private var keyMonitor: Any?
    private let menuBarController = MenuBarController()
    private let tabKeyCode: UInt16 = 48
    private let startupDate = CFAbsoluteTimeGetCurrent()
    private var didLogStartupCompletion = false
    private var isTerminationCleanupRunning = false
    private var didReplyToTermination = false
    private var isUpdateReplacementTermination = false
    private var isDuplicateInstance = false
    private let standardTerminationCleanupTimeout: TimeInterval = 4.0
    private let updateTerminationCleanupTimeout: TimeInterval = 1.5

    private func logStartupStep(_ message: String) {
        let elapsed = CFAbsoluteTimeGetCurrent() - startupDate
        let threadLabel = Thread.isMainThread ? "main" : "background"
        log.info("[StartupTrace] +\(String(format: "%.3f", elapsed))s [\(threadLabel)] \(message)")
    }

    // MARK: - Bind

    func bind(_ appState: AppState) {
        self.appState = appState
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard SingleInstanceController.shared.acquire() else {
            isDuplicateInstance = true
            SingleInstanceController.shared.activateExistingInstance()
            NSApp.terminate(nil)
            return
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicateInstance else { return }
        logStartupStep("applicationDidFinishLaunching begin")

        // Ensure app is a regular Dock citizen from the very start
        NSApp.setActivationPolicy(.regular)
        menuBarController.install()
        MemoryDiagnostics.shared.start()

        UserPreferences.shared.load()
        log.debug("prefs loaded, autoFit=\(UserPreferences.shared.snapshot.autoFitColumnsOnNavigate)")
        logStartupStep("UserPreferences loaded")

        log.debug("restoring security-scoped bookmarks")
        scheduleBookmarkRestore()
        logStartupStep("bookmark restore scheduled")

        log.debug("starting toolbar right-click monitor")
        ToolbarRightClickMonitor.shared.start()
        logStartupStep("toolbar right-click monitor started")

        ContextMenuOptionCoordinator.shared.start()
        logStartupStep("context menu Option monitor started")

        log.debug("installing keyDown monitor for Tab/Backtab")
        installKeyMonitor()
        logStartupStep("key monitor installed")

        installMainWindowObserver()
        logStartupStep("main window observer installed")

        UpdateCoordinator.shared.startAutomaticChecks()
        logStartupStep("automatic update checks scheduled")

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
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMiniaturizeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didDeminiaturizeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidMiniaturize(_:)),
            name: NSWindow.didMiniaturizeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidDeminiaturize(_:)),
            name: NSWindow.didDeminiaturizeNotification,
            object: nil
        )
    }

    @objc private func handleWindowDidBecomeKey(_ notification: Notification) {
        guard !isTerminationCleanupRunning, appState?.isTerminating != true else { return }
        guard let window = notification.object as? NSWindow else { return }
        guard window == NSApp.mainWindow else { return }
        bringAuxiliaryPanelsToFront()
    }

    // MARK: - Main Window Miniaturization
    @objc private func handleWindowDidMiniaturize(_ notification: Notification) {
        guard isMainApplicationWindow(notification.object) else { return }
        MemoryDiagnostics.shared.checkpoint("window.miniaturized.before-trim")
        Task {
            await DirectoryContentCache.shared.clearAll()
            await MainActor.run {
                MemoryDiagnostics.shared.checkpoint("window.miniaturized.after-trim")
                log.info("[WindowLifecycle] minimized — released directory listing cache")
            }
        }
    }

    @objc private func handleWindowDidDeminiaturize(_ notification: Notification) {
        guard !isTerminationCleanupRunning, appState?.isTerminating != true else { return }
        guard isMainApplicationWindow(notification.object) else { return }
        log.info("[WindowLifecycle] restored — rebuilding panel views and refreshing scanner")
        NotificationCenter.default.post(name: .mainWindowDidRestore, object: nil)
        appState?.forceRefreshBothPanels()
        MemoryDiagnostics.shared.checkpoint("window.restored")
    }

    private func isMainApplicationWindow(_ object: Any?) -> Bool {
        guard let window = object as? NSWindow, !(window is NSPanel) else { return false }
        return window.identifier?.rawValue.hasPrefix("main-AppWindow") == true
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
        MultiRenameCoordinator.shared.bringToFront()
        SettingsCoordinator.shared.bringToFront()
        ToolbarCustomizeCoordinator.shared.bringToFront()
        MediaInfoPanel.shared.bringToFront()
    }

    // MARK: - Termination

    func prepareForUpdateReplacementTermination() {
        isUpdateReplacementTermination = true
        log.info("[Update] app delegate prepared for update replacement termination")
    }

    /// Returns .terminateLater so we can do async cleanup before exit.
    /// All work must complete and call reply(.now) within the OS timeout (~5 s).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isDuplicateInstance {
            return .terminateNow
        }
        if isTerminationCleanupRunning {
            log.info("[AppDelegate] applicationShouldTerminate — cleanup already running")
            return .terminateLater
        }

        isTerminationCleanupRunning = true
        appState?.beginTermination()
        NSApp.hide(nil)
        let timeout = isUpdateReplacementTermination ? updateTerminationCleanupTimeout : standardTerminationCleanupTimeout
        log.info("[AppDelegate] applicationShouldTerminate — starting async cleanup timeout=\(timeout)s update=\(isUpdateReplacementTermination)")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            Task { @MainActor [weak self] in
                self?.replyToTerminationOnce(reason: "cleanup timeout \(timeout)s")
            }
        }

        Task { [weak self] in
            guard let self else {
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
                return
            }

            await performCleanupBeforeExit()
            replyToTerminationOnce(reason: "cleanup complete")
        }
        return .terminateLater
    }

    private func replyToTerminationOnce(reason: String) {
        guard !didReplyToTermination else {
            log.info("[AppDelegate] terminate reply skipped reason='\(reason)'")
            return
        }
        didReplyToTermination = true
        log.info("[AppDelegate] cleanup done — replying .now reason='\(reason)'")
        NSApplication.shared.reply(toApplicationShouldTerminate: true)
    }

    /// Synchronously saves state + stops watchers, then resolves async resources.
    /// Must finish in well under 5 s to avoid macOS force-killing the process.
    private func performCleanupBeforeExit() async {
        MemoryDiagnostics.shared.checkpoint("application.termination")
        MemoryDiagnostics.shared.stop()
        // 1. Save panel state and cache — synchronous, fast
        log.info("[AppDelegate] cleanup step save state begin")
        appState?.saveBeforeExit()
        log.info("[AppDelegate] cleanup step save state done")
        // 2. Stop scanner timers and FSEvents streams — synchronous actor work
        log.info("[AppDelegate] cleanup step directory size shutdown begin")
        await DirectorySizeService.shared.shutdown()
        log.info("[AppDelegate] cleanup step directory size shutdown done")
        if let scanner = appState?.scanner {
            log.info("[AppDelegate] cleanup step scanner stop begin")
            await scanner.stopMonitoring()
            log.info("[AppDelegate] cleanup step scanner stop done")
        }
        // 3. Cleanup extracted archive temp dirs — actor hop, fast
        log.info("[AppDelegate] cleanup step archive cleanup begin")
        await ArchiveManager.shared.cleanup()
        log.info("[AppDelegate] cleanup step archive cleanup done")
        // 4. Release security-scoped bookmarks — actor hop, fast
        log.info("[AppDelegate] cleanup step bookmarks stop begin")
        await BookmarkStore.shared.stopAll()
        log.info("[AppDelegate] cleanup step bookmarks stop done")
        // 6. Flush file loggers before the process exits so /tmp mirror is complete
        log.info("[AppDelegate] cleanup step log flush begin")
        LogKit.flush(timeoutSeconds: 2)
        log.info("[AppDelegate] performCleanupBeforeExit complete")
    }

    // MARK: - applicationWillTerminate — key monitor cleanup only

    func applicationWillTerminate(_ notification: Notification) {
        SingleInstanceController.shared.release()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
    }
}
