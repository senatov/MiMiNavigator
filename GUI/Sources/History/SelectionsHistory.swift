// SelectionsHistory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 03.08.2024.
//  Copyright © 2024-2026 Senatov. All rights reserved.
//  Description: Navigation history with JSON file persistence (~/.mimi/mimi_history.json).

import Foundation

// MARK: - SelectionsHistory
@MainActor
@Observable
final class SelectionsHistory {
    @ObservationIgnored
    private var backStack: [URL] = []
    @ObservationIgnored
    private var forwardStack: [URL] = []
    private(set) var current: URL?
    private(set) var canGoBack: Bool = false
    private(set) var canGoForward: Bool = false
    private var recentSelections: [URL] = []
    private static let maxEntries = 255
    // MARK: - JSON file path
    @ObservationIgnored
    private static let historyFileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mimi_history.json")
    }()
    // MARK: - Codable DTO
    private struct HistoryDTO: Codable {
        var backStack: [String]
        var forwardStack: [String]
        var current: String?
        var recentSelections: [String]
    }

    // MARK: - Path helpers
    private static func ensureHistoryDirectoryExists() {
        let directoryURL = historyFileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            log.error("[SelectionsHistory] failed to create history directory: \(error.localizedDescription)")
        }
    }

    private static func makeFileURL(from path: String) -> URL {
        URL(filePath: path, directoryHint: .inferFromPath, relativeTo: nil)
    }
    // MARK: - Init
    init() {
        Self.ensureHistoryDirectoryExists()
        loadFromDisk()
        log.info("[SelectionsHistory] loaded \(recentSelections.count) recent, back=\(backStack.count), fwd=\(forwardStack.count)")
    }
    // MARK: - Core visit logic
    private func visit(_ url: URL, recordHistory: Bool) {
        let normalized = url.standardizedFileURL
        if current?.standardizedFileURL == normalized { return }
        if recordHistory {
            guard normalized.hasDirectoryPath else { return }
            if let current, backStack.last != current {
                backStack.append(current)
            }
            forwardStack.removeAll()
            trimHistory()
        }
        // Always track in recentSelections for the History dialog
        if let idx = recentSelections.firstIndex(where: { $0.standardizedFileURL == normalized }) {
            recentSelections.remove(at: idx)
        }
        recentSelections.insert(normalized, at: 0)
        if recentSelections.count > Self.maxEntries {
            recentSelections.removeLast()
        }
        current = normalized
        updateNavigationState()
        saveToDisk()
    }
    // MARK: - Navigate
    func navigate(to url: URL) {
        visit(url, recordHistory: true)
    }
    // MARK: - Set Current
    func setCurrent(to url: URL) {
        visit(url, recordHistory: false)
    }
    // MARK: - Back
    func goBack() -> URL? {
        guard let prev = backStack.popLast() else { return nil }
        if let current { forwardStack.append(current) }
        current = prev
        updateNavigationState()
        saveToDisk()
        return prev
    }
    // MARK: - Forward
    func goForward() -> URL? {
        guard let next = forwardStack.popLast() else { return nil }
        if let current { backStack.append(current) }
        current = next
        updateNavigationState()
        saveToDisk()
        return next
    }
    // MARK: - History lists for UI
    func getBackHistory(limit: Int = 10) -> [URL] {
        Array(backStack.suffix(limit).reversed())
    }
    func getForwardHistory(limit: Int = 10) -> [URL] {
        Array(forwardStack.suffix(limit))
    }
    // MARK: - Recent selections (all entries, no limit)
    func getRecentSelections() -> [URL] {
        recentSelections
    }
    // MARK: - Remove entry
    func remove(_ url: URL) {
        let normalized = url.standardizedFileURL
        recentSelections.removeAll { $0.standardizedFileURL == normalized }
        saveToDisk()
    }
    // MARK: - Trim
    private func trimHistory() {
        if backStack.count > Self.maxEntries {
            backStack.removeFirst(backStack.count - Self.maxEntries)
        }
    }
    // MARK: - Update Navigation State
    private func updateNavigationState() {
        canGoBack = !backStack.isEmpty
        canGoForward = !forwardStack.isEmpty
    }
    // MARK: - Clear
    func clear() {
        backStack.removeAll()
        forwardStack.removeAll()
        recentSelections.removeAll()
        current = nil
        updateNavigationState()
        saveToDisk()
    }
    // MARK: - Save to JSON
    private func saveToDisk() {
        Self.ensureHistoryDirectoryExists()
        let dto = HistoryDTO(
            backStack: backStack.map(\.path),
            forwardStack: forwardStack.map(\.path),
            current: current?.path,
            recentSelections: recentSelections.map(\.path)
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(dto)
            try data.write(to: Self.historyFileURL, options: .atomic)
        } catch {
            log.error("[SelectionsHistory] save failed: \(error.localizedDescription)")
        }
    }
    // MARK: - Load from JSON
    private func loadFromDisk() {
        Self.ensureHistoryDirectoryExists()

        let fileURL = Self.historyFileURL
        do {
            let data = try Data(contentsOf: fileURL)
            let dto = try JSONDecoder().decode(HistoryDTO.self, from: data)
            backStack = dto.backStack.map(Self.makeFileURL(from:))
            forwardStack = dto.forwardStack.map(Self.makeFileURL(from:))
            current = dto.current.map(Self.makeFileURL(from:))
            recentSelections = dto.recentSelections.map(Self.makeFileURL(from:))
            updateNavigationState()
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            saveToDisk()
        } catch {
            log.error("[SelectionsHistory] load failed: \(error.localizedDescription)")
            backStack.removeAll()
            forwardStack.removeAll()
            recentSelections.removeAll()
            current = nil
            updateNavigationState()
            saveToDisk()
        }
    }
}
