// SpinnerWatchdog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Monitors BatchOperationManager and any other @Observable sources for spinner
//   activation. Logs WARN immediately when a spinner appears so the developer can trace
//   which code path triggered it without adding manual logging at every call site.
//
// Usage:
//   SpinnerWatchdog.shared.start()   ← call once from AppState.initialize()
//   SpinnerWatchdog.shared.stop()    ← call from saveBeforeExit() if desired

import Foundation

// MARK: - Spinner Watchdog

/// Passive diagnostic service that emits a WARN log the moment any app-wide spinner
/// becomes visible. Uses a polling timer (50 ms) against registered closures —
/// lightweight enough to leave enabled in release builds.
final class SpinnerWatchdog: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = SpinnerWatchdog()

    // MARK: - Internal state

    private var timer: DispatchSourceTimer?
    private var lastKnownState: [String: Bool] = [:]
    private let queue = DispatchQueue(label: "mimi.spinner.watchdog", qos: .utility)
    private var sources: [(name: String, isActive: () -> Bool)] = []
    private let lock = NSLock()

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Register a named spinner source.
    /// The isActive closure is evaluated on a background queue every 50 ms.
    func addSource(name: String, isActive: @escaping () -> Bool) {
        lock.lock()
        defer { lock.unlock() }
        sources.append((name: name, isActive: isActive))
        log.info("[SpinnerWatchdog] registered source: '\(name)'")
    }

    /// Start polling. Safe to call multiple times — no-op if already running.
    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(50))
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
        log.info("[SpinnerWatchdog] started — polling \(sources.count) source(s) every 50 ms")
    }

    /// Stop polling.
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        timer?.cancel()
        timer = nil
        log.info("[SpinnerWatchdog] stopped")
    }

    // MARK: - Polling

    private func poll() {
        lock.lock()
        let snapshot = sources
        lock.unlock()
        for source in snapshot {
            let active = source.isActive()
            let prev = lastKnownState[source.name] ?? false
            if active && !prev {
                // Grab top frames for a quick hint — don't use full backtrace (too expensive at 50ms)
                let frames = Thread.callStackSymbols.prefix(5).joined(separator: "\n    ")
                log.warning("[SpinnerWatchdog] ⚠️ SPINNER APPEARED: '\(source.name)'\n    \(frames)")
            } else if !active && prev {
                log.info("[SpinnerWatchdog] ✅ spinner dismissed: '\(source.name)'")
            }
            lastKnownState[source.name] = active
        }
    }
}
