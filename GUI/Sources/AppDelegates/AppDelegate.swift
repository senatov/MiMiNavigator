// AppDelegate.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.10.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: NSApplicationDelegate. Handles Tab key interception, bookmark restore,
//   and companion panel visibility (Network Neighborhood, Find Files).
//   Auxiliary windows follow standard macOS ordering and are raised only by explicit user actions.
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
    private var mainWindowMouseMonitor: Any?
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
        Task {
            await TemporaryArtifactCleaner.cleanup(reason: "startup")
        }

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

        installMainWindowMouseMonitor()
        logStartupStep("main window mouse monitor installed")

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
            if event.keyCode == 53, InAppNoticeCenter.shared.isHistoryVisible {
                InAppNoticeCenter.shared.hideHistory()
                return nil
            }
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
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMiniaturizeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didDeminiaturizeNotification, object: nil)
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

    private func installMainWindowMouseMonitor() {
        if let mainWindowMouseMonitor { NSEvent.removeMonitor(mainWindowMouseMonitor) }
        mainWindowMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let mainWindow = event.window, mainWindow.isKeyWindow, self.isMainApplicationWindow(mainWindow) else { return event }
            log.debug("[WindowOrdering] repeated main window click detected")
            self.scheduleStandaloneWindowOrdering(relativeTo: mainWindow)
            return event
        }
    }

    // MARK: - Main Window Focus
    func applicationDidBecomeActive(_ notification: Notification) {
        let mainWindow = NSApp.windows.first { isMainApplicationWindow($0) }
        scheduleStandaloneWindowOrdering(relativeTo: mainWindow)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        log.info("[MainWindow] reopen requested without visible windows")
        MainWindowPresenter.shared.open()
        return true
    }

    private func scheduleStandaloneWindowOrdering(relativeTo mainWindow: NSWindow?) {
        guard !isTerminationCleanupRunning, appState?.isTerminating != true, let mainWindow else { return }
        DispatchQueue.main.async { [weak self, weak mainWindow] in
            guard let self, let mainWindow, NSApp.isActive, mainWindow.isVisible else { return }
            self.restoreStandaloneWindowOrdering(relativeTo: mainWindow)
        }
    }

    private func restoreStandaloneWindowOrdering(relativeTo mainWindow: NSWindow) {
        let standalonePanels = NSApp.windows.compactMap { $0 as? NSPanel }.filter {
            $0.isVisible && WindowPresentationPolicy.isStandalone($0) && $0 !== mainWindow
        }
        guard !standalonePanels.isEmpty else { return }
        for panel in standalonePanels.reversed() {
            panel.order(.above, relativeTo: mainWindow.windowNumber)
        }
        log.debug("[WindowOrdering] restored \(standalonePanels.count) standalone panels above main window")
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
        guard window.contentView != nil, window.styleMask.contains(.titled) else { return false }
        return true
    }

    private func logStartupCompletionIfNeeded(reason: String) {
        guard !didLogStartupCompletion else { return }
        didLogStartupCompletion = true
        logStartupStep("startup checkpoint reached: \(reason)")
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
        log.info("[AppDelegate] cleanup step temporary artifacts begin")
        await TemporaryArtifactCleaner.cleanup(reason: "termination")
        log.info("[AppDelegate] cleanup step temporary artifacts done")
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
        if let mainWindowMouseMonitor { NSEvent.removeMonitor(mainWindowMouseMonitor) }
        keyMonitor = nil
        mainWindowMouseMonitor = nil
        NotificationCenter.default.removeObserver(self)
    }
}
