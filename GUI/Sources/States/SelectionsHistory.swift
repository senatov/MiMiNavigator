// SelHistory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 03.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Foundation

// MARK: - SelectionsHistory
@MainActor
@Observable
final class SelectionsHistory {
    private(set) var recentSelections: [String] = []
    private var entries: [HistoryEntry] = []
    private var currentIndex: Int?
    private let userDefaultsKey = "SelectionsHistory.v2"
    private let maxEntries = 32

    // MARK: - Init
    init() {
        log.info(#function + " - Initializing SelectionsHistory")
        load()
        rebuildRecentSelections()
    }

    // MARK: - Public API (compatibility)
    func add(_ path: String) {
        log.debug(#function)
        let norm = normalize(path)
        guard !norm.isEmpty else { return }
        log.info(#function + " - \(norm)")
        // Build snapshot (best-effort)
        let snap = makeSnapshot(for: norm)
        // Ensure uniqueness: remove all existing occurrences of this path (including deleted ones).
        if let firstIdx = entries.firstIndex(where: { $0.path == norm }) {
            // Remove all dupes except the first occurrence to simplify index math.
            var i = entries.count - 1
            while i >= 0 {
                if i != firstIdx && entries[i].path == norm {
                    entries.remove(at: i)
                }
                i -= 1
            }
        }
        if let idx = entries.firstIndex(where: { $0.path == norm }) {
            // Existing path: update status and move to front if not already first
            log.debug(#function + " - updating existing entry at index \(idx)")
            var e = entries[idx]
            let was = e.snapshot
            if was != snap {
                e.status = .modified
                e.snapshot = snap
            } else {
                // Revisit without changes — считать как added для «последнего посещения»
                e.status = .added
            }
            e.timestamp = Date()
            entries.remove(at: idx)
            entries.insert(e, at: 0)
            currentIndex = 0
        } else {
            // New path
            let e = HistoryEntry(path: norm, timestamp: Date(), status: .added, snapshot: snap)
            entries.insert(e, at: 0)
            currentIndex = 0
        }
        // Trim
        while entries.count > maxEntries {
            _ = entries.popLast()
        }
        if let ci = currentIndex, ci >= entries.count {
            currentIndex = entries.isEmpty ? nil : (entries.count - 1)
        }
        save()
    }
    // MARK: - Convenience accessors used elsewhere
    var last: String? { entries.first(where: { $0.status != .deleted })?.path }
    var current: String? {
        guard let ci = currentIndex, ci >= 0, ci < entries.count else { return nil }
        let e = entries[ci]
        return e.status == .deleted ? nil : e.path
    }

    // MARK: -
    var firstNonDeleted: String? {
        log.debug(#function)
        guard let lastIndex = entries.indices.last else { return nil }
        // "first" in user terms = oldest non-deleted
        for i in stride(from: lastIndex, through: 0, by: -1) {
            let e = entries[i]
            if e.status != .deleted { return e.path }
        }
        return nil
    }

    // MARK: - Navigation
    @discardableResult
    func firstPath() -> String? {
        log.debug(#function)
        guard !entries.isEmpty else { return nil }
        // Move to oldest non-deleted
        for i in stride(from: entries.count - 1, through: 0, by: -1) {
            if entries[i].status != .deleted {
                currentIndex = i
                save()
                return entries[i].path
            }
        }
        return nil
    }

    // MARK: -
    @discardableResult
    func lastPath() -> String? {
        log.debug(#function)
        // Most recent non-deleted (head)
        guard let e = entries.first(where: { $0.status != .deleted }) else { return nil }
        if let idx = entries.firstIndex(of: e) { currentIndex = idx }
        save()
        return e.path
    }

    // MARK: -
    @discardableResult
    func previousPath() -> String? {
        log.debug(#function)
        guard !entries.isEmpty else { return nil }
        let start = (currentIndex ?? 0)
        var i = start + 1
        while i < entries.count {
            if entries[i].status != .deleted {
                currentIndex = i
                save()
                return entries[i].path
            }
            i += 1
        }
        return nil
    }

    // MARK: -
    @discardableResult
    func nextPath() -> String? {
        log.debug(#function)
        guard !entries.isEmpty else { return nil }
        let start = (currentIndex ?? 0)
        var i = max(start - 1, 0)
        while i >= 0 {
            if entries[i].status != .deleted {
                currentIndex = i
                save()
                return entries[i].path
            }
            i -= 1
        }
        return nil
    }

    // MARK: -
    func setCurrent(to path: String) {
        log.debug(#function)
        let norm = normalize(path)
        if let idx = entries.firstIndex(where: { $0.path == norm && $0.status != .deleted }) {
            currentIndex = idx
            save()
        }
    }

    // MARK: - Status management
    func markDeleted(path: String) {
        log.debug(#function)
        let norm = normalize(path)
        guard let idx = entries.firstIndex(where: { $0.path == norm }) else { return }
        entries[idx].status = .deleted
        entries[idx].timestamp = Date()
        if currentIndex == idx { currentIndex = nil }
        save()
    }

    // MARK: -
    func markModified(path: String) {
        log.debug(#function)
        let norm = normalize(path)
        guard let idx = entries.firstIndex(where: { $0.path == norm }) else { return }
        entries[idx].status = .modified
        entries[idx].snapshot = makeSnapshot(for: norm)
        entries[idx].timestamp = Date()
        save()
    }

    // MARK: -
    func remove(path: String) {
        log.debug(#function)
        let norm = normalize(path)
        if let idx = entries.firstIndex(where: { $0.path == norm }) {
            entries.remove(at: idx)
            if let ci = currentIndex { if idx < ci { currentIndex = ci - 1 } else if idx == ci { currentIndex = nil } }
            save()
        }
    }

    // MARK: -
    func clear() {
        log.debug(#function)
        entries.removeAll()
        currentIndex = nil
        save()
    }

    // MARK: - Persistence
    private func save() {
        log.debug(#function)
        rebuildRecentSelections()
        let persisted = Persisted(entries: entries, currentIndex: currentIndex)
        do {
            let data = try JSONEncoder().encode(persisted)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            log.info(#function + " - saved \(entries.count) entries, currentIndex=\(String(describing: currentIndex))")
        } catch { log.error("SelectionsHistory.save: \(error.localizedDescription)") }
    }

    // MARK: -
    private func load() {
        log.debug(#function)
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            // Backward-compat: try to migrate old plain string array if present
            migrateFromV1()
            return
        }
        do {
            let persisted = try JSONDecoder().decode(Persisted.self, from: data)
            self.entries = persisted.entries
            self.currentIndex = persisted.currentIndex
            log.info(#function + " - loaded \(entries.count) entries, currentIndex=\(String(describing: currentIndex))")
            rebuildRecentSelections()
        } catch {
            log.error("SelectionsHistory.load decode failed: \(error.localizedDescription)")
            // Fallback: clear
            self.entries = []
            self.currentIndex = nil
            rebuildRecentSelections()
        }
    }

    // MARK: -
    private func migrateFromV1() {
        log.debug(#function)
        let oldKey = "SelectionsHistory"
        if let arr = UserDefaults.standard.stringArray(forKey: oldKey) {
            log.info("Migrating legacy SelectionsHistory (\(arr.count) items)")
            let now = Date()
            let mapped: [HistoryEntry] = arr.map { p in
                HistoryEntry(path: normalize(p), timestamp: now, status: .added, snapshot: makeSnapshot(for: p))
            }
            self.entries = Array(mapped.prefix(maxEntries))
            self.currentIndex = self.entries.isEmpty ? nil : 0
            // Remove old payload
            UserDefaults.standard.removeObject(forKey: oldKey)
            save()
        } else {
            self.entries = []
            self.currentIndex = nil
            rebuildRecentSelections()
        }
    }

    // MARK: - Helpers
    private func normalize(_ path: String) -> String {
        log.debug(#function)
        // Accept both URL string and path; prefer standardized file path
        if let url = URL(string: path), url.isFileURL {
            return url.standardized.resolvingSymlinksInPath().path
        } else {
            return (path as NSString).standardizingPath
        }
    }

    // MARK: -
    private func makeSnapshot(for path: String) -> FileSnapshot? {
        log.debug(#function)
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
            // For dirs, snapshot can be nil (we don't compute aggregate size)
            // For non-existing paths, also nil
            return nil
        }
        if let attrs = try? fm.attributesOfItem(atPath: path) {
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let mtime = attrs[.modificationDate] as? Date
            return FileSnapshot(size: size, mtime: mtime)
        }
        return nil
    }

    // MARK: -
    private func rebuildRecentSelections() {
        log.debug(#function)
        // Publish non-deleted paths in curr order
        let list = entries.filter { $0.status != .deleted }.map { $0.path }
        if recentSelections != list { recentSelections = list }
    }
}
