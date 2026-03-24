// PanelNavigationHistory.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Per-panel navigation history for Back/Forward buttons

import FileModelKit
import Foundation

// MARK: - Per-Panel Navigation History
/// Manages browser-style back/forward navigation for a single panel
@MainActor
@Observable
final class PanelNavigationHistory {

    // Debounced save support
    private var saveTask: Task<Void, Never>? = nil
    private let saveDelay: UInt64 = 300_000_000  // 300ms

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: saveDelay)
            self.save()
        }
    }
    private let panel: FavPanelSide
    private let userDefaultsKey: String

    /// Stack of visited paths (oldest first, newest last)
    private var history: [URL] = []

    /// Current position in history (points to current path)
    private var currentIndex: Int = -1 {
        didSet {
            updateNavigationState()
        }
    }

    // MARK: - Navigation State (stored for SwiftUI reactivity)

    private(set) var canGoBack: Bool = false
    private(set) var canGoForward: Bool = false

    private func updateNavigationState() {
        canGoBack = currentIndex > 0
        canGoForward = currentIndex < history.count - 1
    }

    var currentPath: URL? {
        guard currentIndex >= 0, currentIndex < history.count else { return nil }
        return history[currentIndex]
    }

    // MARK: - Init

    init(panel: FavPanelSide) {
        self.panel = panel
        self.userDefaultsKey = "PanelNavigationHistory.\(panel)"
        load()
        log.debug("\(#function) panel=\(panel) loaded \(history.count) entries, currentIndex=\(currentIndex)")
    }

    deinit {
        MainActor.assumeIsolated {
            saveTask?.cancel()
        }
    }

    // MARK: - Navigation

    private func isValidDirectory(_ url: URL) -> Bool {
        if AppState.isRemotePath(url) {
            return true
        }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            && isDir.boolValue
    }

    /// Navigate to a new path (called when user enters a directory)
    func navigateTo(_ url: URL, record: Bool = true) {
        let normalized = url.standardizedFileURL

        guard isValidDirectory(normalized) else {
            log.warning("[History] skip invalid path: \(normalized.path)")
            return
        }

        log.debug("\(#function) panel=\(panel) path=\(normalized.path) currentIndex=\(currentIndex) historyCount=\(history.count)")

        // If we're not at the end, truncate forward history
        if currentIndex < history.count - 1 {
            log.debug("\(#function) truncating forward history from index \(currentIndex + 1)")
            history = Array(history.prefix(currentIndex + 1))
            updateNavigationState()
        }

        // Don't add duplicate of current path
        if currentPath == normalized {
            log.debug("\(#function) panel=\(panel) skip duplicate current: \(normalized)")
            return
        }

        if record {
            history.append(normalized)
            currentIndex = history.count - 1

            let maxEntries = 100
            if history.count > maxEntries {
                let removeCount = history.count - maxEntries
                history.removeFirst(removeCount)
                currentIndex -= removeCount
            }

            scheduleSave()
        }
        if record {
            log.info(
                "\(#function) panel=\(panel) added: \(normalized.path.components(separatedBy: "/").suffix(3).joined(separator: "/")) index=\(currentIndex)/\(history.count)"
            )
        } else {
            log.debug("\(#function) panel=\(panel) navigated (no record): \(normalized.path)")
        }
    }

    /// Go back in history, returns path to navigate to
    @discardableResult
    func goBack() -> URL? {
        log.debug("\(#function) panel=\(panel) canGoBack=\(canGoBack) currentIndex=\(currentIndex) historyCount=\(history.count)")

        guard canGoBack else {
            log.debug("\(#function) panel=\(panel) cannot go back")
            return nil
        }

        currentIndex -= 1
        scheduleSave()

        let path = history[currentIndex]
        log.info("\(#function) panel=\(panel) → \(path) index=\(currentIndex)")
        return path
    }

    /// Go forward in history, returns path to navigate to
    @discardableResult
    func goForward() -> URL? {
        log.debug(
            "\(#function) panel=\(panel) canGoForward=\(canGoForward) currentIndex=\(currentIndex) historyCount=\(history.count)")

        guard canGoForward else {
            log.debug("\(#function) panel=\(panel) cannot go forward")
            return nil
        }

        currentIndex += 1
        scheduleSave()

        let path = history[currentIndex]
        log.info("\(#function) panel=\(panel) → \(path) index=\(currentIndex)")
        return path
    }

    /// Get back history for dropdown menu
    func getBackHistory(limit: Int = 10) -> [URL] {
        guard currentIndex > 0 else { return [] }
        let start = max(0, currentIndex - limit)
        return Array(history[start..<currentIndex].reversed())
    }

    /// Get forward history for dropdown menu
    func getForwardHistory(limit: Int = 10) -> [URL] {
        guard currentIndex < history.count - 1 else { return [] }
        let end = min(history.count, currentIndex + 1 + limit)
        return Array(history[(currentIndex + 1)..<end])
    }

    /// Jump to specific path in history (for dropdown menu)
    func jumpTo(_ url: URL) -> Bool {
        let normalized = url.standardizedFileURL
        if let idx = history.firstIndex(where: { $0.standardizedFileURL == normalized }) {
            currentIndex = idx
            save()
            log.debug("\(#function) panel=\(panel) jumped to index=\(idx)")
            return true
        }
        return false
    }

    // MARK: - Persistence

    private func save() {
        let data: [String: Any] = [
            "history": history.map { $0.path },
            "currentIndex": currentIndex,
        ]
        MiMiDefaults.shared.set(data, forKey: userDefaultsKey)
    }

    private func load() {
        guard let data = MiMiDefaults.shared.dictionary(forKey: userDefaultsKey),
            let hist = data["history"] as? [String],
            let idx = data["currentIndex"] as? Int
        else {
            return
        }

        // Validate paths exist (allow remote paths through)
        history = hist.compactMap { path in
            let url = URL(fileURLWithPath: path)
            if AppState.isRemotePath(url) {
                return url
            }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
            return nil
        }

        // Adjust index if needed
        if history.isEmpty {
            currentIndex = -1
        } else if idx >= history.count {
            currentIndex = history.count - 1
        } else if idx < 0 {
            currentIndex = 0
        } else {
            currentIndex = idx
        }
        updateNavigationState()
    }

    /// Clear history (for testing or reset)
    func clear() {
        history.removeAll()
        currentIndex = -1
        save()
    }
}
