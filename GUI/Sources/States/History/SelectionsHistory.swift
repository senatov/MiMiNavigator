// SelectionsHistory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 03.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import Foundation

// MARK: - Navigation history manager
@MainActor
@Observable
final class SelectionsHistory {
    private(set) var recentSelections: [String] = []
    private var entries: [HistoryEntry] = []
    private var currentIndex: Int?
    private let userDefaultsKey = "SelectionsHistory.v2"

    // MARK: - Navigation state
    var canGoBack: Bool {
        guard let idx = currentIndex else { return false }
        return idx < entries.count - 1
    }

    var canGoForward: Bool {
        guard let idx = currentIndex else { return false }
        return idx > 0
    }

    // MARK: - Init
    init() {
        load()
        rebuildRecentSelections()
    }

    // MARK: - Go back in history
    func goBack() -> String? {
        guard canGoBack, let idx = currentIndex else { return nil }
        
        var newIdx = idx + 1
        while newIdx < entries.count && entries[newIdx].status == .deleted {
            newIdx += 1
        }
        guard newIdx < entries.count else { return nil }
        
        currentIndex = newIdx
        save()
        return entries[newIdx].path
    }

    // MARK: - Go forward in history
    func goForward() -> String? {
        guard canGoForward, let idx = currentIndex else { return nil }
        
        var newIdx = idx - 1
        while newIdx >= 0 && entries[newIdx].status == .deleted {
            newIdx -= 1
        }
        guard newIdx >= 0 else { return nil }
        
        currentIndex = newIdx
        save()
        return entries[newIdx].path
    }

    // MARK: - Get back history
    func getBackHistory(limit: Int = 10) -> [String] {
        guard let idx = currentIndex else { return [] }
        return entries
            .dropFirst(idx + 1)
            .filter { $0.status != .deleted }
            .prefix(limit)
            .map { $0.path }
    }

    // MARK: - Get forward history
    func getForwardHistory(limit: Int = 10) -> [String] {
        guard let idx = currentIndex, idx > 0 else { return [] }
        return entries
            .prefix(idx)
            .reversed()
            .filter { $0.status != .deleted }
            .prefix(limit)
            .map { $0.path }
    }

    // MARK: - Add path to history (directories only, no duplicates)
    func add(_ path: String) {
        let norm = normalize(path)
        guard !norm.isEmpty else { return }
        
        // Only accept directories
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: norm, isDirectory: &isDir), isDir.boolValue else {
            log.debug("SelectionsHistory: skipping non-directory: \(norm)")
            return
        }
        
        // Check for duplicate (already exists with same normalized path)
        if entries.contains(where: { $0.path == norm && $0.status != .deleted }) {
            // Move existing entry to front instead of adding duplicate
            if let existingIdx = entries.firstIndex(where: { $0.path == norm }) {
                let existing = entries.remove(at: existingIdx)
                var updated = existing
                updated.timestamp = Date()
                updated.status = .added
                entries.insert(updated, at: 0)
                currentIndex = 0
                save()
            }
            return
        }
        
        // Remove any deleted entries with same path
        entries.removeAll { $0.path == norm }
        
        // Add new entry at front
        let entry = HistoryEntry(path: norm, timestamp: Date(), status: .added, snapshot: nil)
        entries.insert(entry, at: 0)
        currentIndex = 0
        
        // Trim to max entries
        let maxEntries = AppConstants.History.maxEntries
        while entries.count > maxEntries {
            entries.removeLast()
        }
        
        save()
    }

    // MARK: - Set current position
    func setCurrent(to path: String) {
        let norm = normalize(path)
        if let idx = entries.firstIndex(where: { $0.path == norm && $0.status != .deleted }) {
            currentIndex = idx
            save()
        }
    }

    // MARK: - Remove path from history
    func remove(_ path: String) {
        let norm = normalize(path)
        entries.removeAll { $0.path == norm }
        
        // Adjust currentIndex if needed
        if let idx = currentIndex, idx >= entries.count {
            currentIndex = entries.isEmpty ? nil : entries.count - 1
        }
        
        save()
    }

    // MARK: - Persistence
    private func save() {
        rebuildRecentSelections()
        let persisted = Persisted(entries: entries, currentIndex: currentIndex)
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let persisted = try? JSONDecoder().decode(Persisted.self, from: data)
        else {
            migrateFromV1()
            return
        }
        self.entries = persisted.entries
        self.currentIndex = persisted.currentIndex
        
        // Clean up: remove files, keep only directories
        cleanupNonDirectories()
        rebuildRecentSelections()
    }

    private func migrateFromV1() {
        let oldKey = "SelectionsHistory"
        if let arr = UserDefaults.standard.stringArray(forKey: oldKey) {
            let now = Date()
            let maxEntries = AppConstants.History.maxEntries
            entries = arr.prefix(maxEntries).compactMap { path in
                let norm = normalize(path)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: norm, isDirectory: &isDir), isDir.boolValue else {
                    return nil
                }
                return HistoryEntry(path: norm, timestamp: now, status: .added, snapshot: nil)
            }
            currentIndex = entries.isEmpty ? nil : 0
            UserDefaults.standard.removeObject(forKey: oldKey)
            save()
        }
    }
    
    // MARK: - Cleanup non-directories from history
    private func cleanupNonDirectories() {
        let beforeCount = entries.count
        entries.removeAll { entry in
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir)
            return !exists || !isDir.boolValue
        }
        
        if entries.count != beforeCount {
            log.debug("SelectionsHistory: cleaned \(beforeCount - entries.count) non-directory entries")
            if let idx = currentIndex, idx >= entries.count {
                currentIndex = entries.isEmpty ? nil : 0
            }
        }
    }

    // MARK: - Helpers
    private func normalize(_ path: String) -> String {
        if let url = URL(string: path), url.isFileURL {
            return url.standardized.resolvingSymlinksInPath().path
        }
        return (path as NSString).standardizingPath
    }

    private func rebuildRecentSelections() {
        let list = entries.filter { $0.status != .deleted }.map { $0.path }
        if recentSelections != list { recentSelections = list }
    }
}
