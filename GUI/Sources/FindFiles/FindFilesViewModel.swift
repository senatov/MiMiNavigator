// FindFilesViewModel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ViewModel for the Find Files panel — bridges UI with FindFilesEngine

import AppKit
import FileModelKit
import Foundation
import SwiftUI

// MARK: - Find Files ViewModel
@MainActor
@Observable
final class FindFilesViewModel {

    // MARK: - Search Parameters (bound to UI)
    var fileNamePattern: String = "*.*"
    var invertFileNamePattern: Bool = false
    var searchText: String = ""
    var searchDirectory: String = ""
    var caseSensitive: Bool = false
    var useRegex: Bool = false
    var searchInSubdirectories: Bool = true
    var searchInArchives: Bool = false
    var itemTypeFilter: FindFilesItemTypeFilter = .filesAndFolders
    var excludeSystemLocations: Bool = false
    var deletableOnly: Bool = false
    var emptyFoldersOnly: Bool = false

    // Size filter
    var useSizeFilter: Bool = false
    var fileSizeMin: String = ""
    var fileSizeMax: String = ""
    var fileSizeUnit: FindFilesSizeUnit = .megabytes

    // Date filter
    var useDateFilter: Bool = false
    var dateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var dateTo: Date = Date()
    var useStaleItemFilter: Bool = false
    var staleCriterionMode: FindFilesStaleCriterionMode = .age
    var staleTimestampFilter: FindFilesTimestampFilter = .both
    var staleAgeAmount: String = ""
    var staleAgeUnit: FindFilesAgeUnit = .months
    var staleSinceDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()

    // MARK: - Results & State
    var results: [FindFilesResult] = []
    var searchState: FindFilesState = .idle
    var stats: FindFilesStats = FindFilesStats()
    var selectedResult: FindFilesResult?
    var selectedResultIDs: Set<FindFilesResult.ID> = []
    var errorMessage: String?

    // MARK: - Persistence
    /// Path where last search results are saved between dialog sessions
    private static let savedResultsURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("search_results.json")
    }()

    /// Header info saved alongside results so Export can show query context
    private(set) var lastSearchSummary: String = ""

    // MARK: - Archive Password Dialog
    var showPasswordDialog: Bool = false
    var passwordArchiveName: String = ""
    var archivePassword: String = ""
    var passwordContinuation: CheckedContinuation<ArchivePasswordResponse, Never>?

    // MARK: - Engine
    private let engine = FindFilesEngine()
    private var searchTask: Task<Void, Never>?
    private var statsUpdateTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        loadPreferences()
    }

    /// Initialize with search directory from active panel.
    /// If selectedFile is an archive, search will be limited to that archive only.
    /// - Parameters:
    ///   - searchPath: Current directory of the active panel
    ///   - selectedFile: Currently selected file (optional)
    func configure(searchPath: String, selectedFile: CustomFile? = nil) {
        // Check if selected file is an archive
        if let file = selectedFile,
            !file.isDirectory,
            isArchiveFile(file)
        {
            // Selected file is an archive — search only inside this archive
            searchDirectory = file.urlValue.path
            searchInArchives = true
            searchInSubdirectories = true
            log.info("[FindFiles] Configured to search in archive: \(file.nameStr)")
        } else if let file = selectedFile, !file.isDirectory {
            // Selected file is a regular file — set it as search target (content search)
            searchDirectory = file.urlValue.path
            searchInArchives = false
            log.info("[FindFiles] Configured to search in file: \(file.nameStr)")
        } else if searchDirectory.isEmpty {
            // Normal case — use panel's current directory
            searchDirectory = searchPath
        }

        // Previous results are NOT loaded automatically.
        // User must press Search to get fresh results.
        // (loadSavedResults is available via explicit "Load Last" action if needed)
    }
    /// Check if file is a recognized archive format
    private func isArchiveFile(_ file: CustomFile) -> Bool {
        let ext = file.urlValue.pathExtension.lowercased()
        if ArchiveExtensions.isArchive(ext) {
            return true
        }
        // Also check compound extensions like .tar.gz
        if ArchiveExtensions.isCompoundArchive(file.nameStr) {
            return true
        }
        return false
    }

    // MARK: - Start Search

    func startSearch() {
        guard searchState != .searching else { return }
        MemoryDiagnostics.shared.checkpoint("search.before")
        log.info("[FindFiles] Starting search: name='\(fileNamePattern)' text='\(searchText)' dir='\(searchDirectory)'")
        errorMessage = nil
        // Validate target path
        let targetURL = URL(fileURLWithPath: searchDirectory)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir)
        // Check if it's a single archive file to search (not a directory)
        let isArchiveTarget = exists && !isDir.boolValue && ArchiveExtensions.isArchive(targetURL.pathExtension.lowercased())
        // Check if it's a single regular file (not archive, not directory)
        let isSingleFileTarget = exists && !isDir.boolValue && !isArchiveTarget
        guard exists && (isDir.boolValue || isArchiveTarget || isSingleFileTarget) else {
            errorMessage = "Path not found: \(searchDirectory)"
            return
        }
        let staleAgeDays = staleAgeDaysIfNeeded()
        guard errorMessage == nil else { return }
        // Save to history
        SearchHistoryManager.shared.add(fileNamePattern, for: .fileNamePattern)
        SearchHistoryManager.shared.add(searchDirectory, for: .searchDirectory)
        if !searchText.isEmpty {
            SearchHistoryManager.shared.add(searchText, for: .searchText)
        }
        // Clear previous results
        results.removeAll()
        selectedResultIDs.removeAll()
        selectedResult = nil
        searchState = .searching
        // Build search summary for export header
        var summaryParts: [String] = []
        if !fileNamePattern.isEmpty && fileNamePattern != "*" && fileNamePattern != "*.*" {
            let nameOperator = invertFileNamePattern ? "NOT " : ""
            summaryParts.append("Name: \(nameOperator)\(fileNamePattern)")
        }
        if !searchText.isEmpty { summaryParts.append("Text: \(searchText)") }
        summaryParts.append("In: \(searchDirectory)")
        lastSearchSummary = summaryParts.joined(separator: " | ")

        // Build criteria
        var criteria = FindFilesCriteria(searchDirectory: targetURL)
        criteria.fileNamePattern = fileNamePattern.isEmpty ? "*" : fileNamePattern
        criteria.invertFileNamePattern = invertFileNamePattern
        criteria.searchText = searchText
        criteria.caseSensitive = caseSensitive
        criteria.useRegex = useRegex
        criteria.searchInSubdirectories = searchInSubdirectories
        criteria.searchInArchives = searchInArchives
        criteria.itemType = itemTypeFilter
        criteria.excludeSystemLocations = excludeSystemLocations
        criteria.deletableOnly = deletableOnly
        criteria.applicationLeftoversOnly = isPresetActive(.applicationLeftovers)
        if criteria.applicationLeftoversOnly {
            criteria.searchDirectories = FindFilesLeftoverSafety.searchDirectories
        }
        criteria.emptyFoldersOnly = emptyFoldersOnly
        criteria.isArchiveOnlySearch = isArchiveTarget
        criteria.isSingleFileContentSearch = isSingleFileTarget

        if useSizeFilter && itemTypeFilter != .foldersOnly {
            let mult = fileSizeUnit.multiplier
            if let v = Int64(fileSizeMin) { criteria.fileSizeMin = v * mult }
            if let v = Int64(fileSizeMax) { criteria.fileSizeMax = v * mult }
        }
        if useDateFilter {
            criteria.dateFrom = dateFrom
            criteria.dateTo = dateTo
        }
        applyStaleCriteria(to: &criteria, staleAgeDays: staleAgeDays)

        // Start async search — detached task keeps stream consumption off MainActor.
        let engine = self.engine

        // Start high-frequency stats polling for live currentPath display
        startStatsPolling()

        searchTask = Task.detached { [weak self] in
            guard let self else { return }

            let stream = await engine.search(
                criteria: criteria,
                passwordCallback: { @concurrent [weak self] archiveName in
                    guard let self else { return .skip }
                    return await self.requestArchivePassword(archiveName: archiveName)
                }
            )

            var batch: [FindFilesResult] = []
            batch.reserveCapacity(500)
            var receivedCount = 0
            for await result in stream {
                guard !Task.isCancelled else { break }
                batch.append(result)
                receivedCount += 1
                if receivedCount >= criteria.resultLimit {
                    await engine.reachResultLimit()
                    break
                }
                if batch.count >= 500 {
                    let chunk = batch
                    batch.removeAll(keepingCapacity: true)
                    let currentStats = await engine.getStats()
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.results.append(contentsOf: chunk)
                        self.stats = currentStats
                    }
                }
            }

            // Final flush — append any remaining results
            let remaining = batch
            let finalStats = await engine.getStats()
            await MainActor.run { [weak self] in
                guard let self else { return }
                if !remaining.isEmpty {
                    self.results.append(contentsOf: remaining)
                }
                self.stats = finalStats
                // Stop stats polling
                self.stopStatsPolling()
                // Only update state if not already cancelled by user action
                if self.searchState != .cancelled {
                    if Task.isCancelled {
                        self.searchState = .cancelled
                    } else {
                        self.searchState = .completed
                        if self.results.count <= 10_000 {
                            self.saveResults()
                        } else {
                            log.info("[FindFiles] Skipped automatic JSON save for \(self.results.count) results")
                        }
                    }
                }
                MemoryDiagnostics.shared.checkpoint("search.after")
                log.info("[FindFiles] Search finished: \(self.results.count) results, \(self.stats.formattedElapsed)")
            }
        }
    }

    // MARK: - Cancel Search

    func cancelSearch() {
        cancelPasswordRequest()
        guard searchState == .searching else { return }
        log.info("[FindFiles] Cancelling search")
        // 1. Immediately update UI state — stops animation
        searchState = .cancelled
        // 2. Stop stats polling
        stopStatsPolling()
        // 3. Cancel the Swift task (stops iteration in startSearch)
        searchTask?.cancel()
        searchTask = nil
        // 4. Kill the find process via engine (SIGKILL, no waiting)
        Task {
            await engine.cancel()
        }
    }

    // MARK: - Cancel Password Request
    private func cancelPasswordRequest() {
        showPasswordDialog = false
        guard let continuation = passwordContinuation else { return }
        passwordContinuation = nil
        continuation.resume(returning: .skip)
    }

    // MARK: - Stats Polling
    /// High-frequency polling for live currentPath updates in status bar
    private func startStatsPolling() {
        stopStatsPolling()
        let engine = self.engine
        statsUpdateTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.searchState == .searching else { break }
                let currentStats = await engine.getStats()
                self.stats = currentStats
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    private func stopStatsPolling() {
        statsUpdateTask?.cancel()
        statsUpdateTask = nil
    }

    // MARK: - Clear Results

    func clearResults() {
        stopStatsPolling()
        cancelSearch()
        results.removeAll()
        selectedResultIDs.removeAll()
        selectedResult = nil
        searchState = .idle
        errorMessage = nil
        stats = FindFilesStats()
    }

    // MARK: - Advanced Presets

    func applyPotentialBallastPreset() {
        applyLargeStaleFilesPreset()
    }

    func applyLargeStaleFilesPreset() {
        fileNamePattern = "*"
        searchText = ""
        searchDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        caseSensitive = false
        useRegex = false
        searchInSubdirectories = true
        searchInArchives = false
        itemTypeFilter = .filesOnly
        excludeSystemLocations = true
        deletableOnly = true
        emptyFoldersOnly = false
        useSizeFilter = true
        fileSizeMin = "100"
        fileSizeMax = ""
        fileSizeUnit = .megabytes
        useDateFilter = false
        useStaleItemFilter = true
        staleCriterionMode = .age
        staleTimestampFilter = .both
        staleAgeAmount = "12"
        staleAgeUnit = .months
    }

    func applyApplicationLeftoversPreset() {
        fileNamePattern = "*"
        searchText = ""
        searchDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true).path
        caseSensitive = false
        useRegex = false
        searchInSubdirectories = false
        searchInArchives = false
        itemTypeFilter = .filesAndFolders
        excludeSystemLocations = true
        deletableOnly = true
        emptyFoldersOnly = false
        useSizeFilter = false
        useDateFilter = false
        useStaleItemFilter = true
        staleCriterionMode = .age
        staleTimestampFilter = .modified
        staleAgeAmount = "24"
        staleAgeUnit = .months
    }

    func applyEmptyStaleFoldersPreset() {
        fileNamePattern = "*"
        searchText = ""
        searchDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        caseSensitive = false
        useRegex = false
        searchInSubdirectories = true
        searchInArchives = false
        itemTypeFilter = .foldersOnly
        excludeSystemLocations = true
        deletableOnly = true
        emptyFoldersOnly = true
        useSizeFilter = false
        useDateFilter = false
        useStaleItemFilter = true
        staleCriterionMode = .age
        staleTimestampFilter = .modified
        staleAgeAmount = "12"
        staleAgeUnit = .months
    }

    private func ageInDays(amount: String, unit: FindFilesAgeUnit) -> Int? {
        guard let value = Int(amount.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
            return nil
        }
        switch unit {
        case .days:
            return value
        case .months:
            return value * 30
        case .years:
            return value * 365
        }
    }

    private func staleAgeDaysIfNeeded() -> Int? {
        guard useStaleItemFilter, staleCriterionMode == .age else { return nil }
        guard let days = ageInDays(amount: staleAgeAmount, unit: staleAgeUnit) else {
            errorMessage = "Enter a positive age value."
            return nil
        }
        return days
    }

    private func applyStaleCriteria(to criteria: inout FindFilesCriteria, staleAgeDays: Int?) {
        guard useStaleItemFilter else { return }
        let appliesToModified = staleTimestampFilter == .modified || staleTimestampFilter == .both
        let appliesToAccessed = staleTimestampFilter == .accessed || staleTimestampFilter == .both

        switch staleCriterionMode {
        case .age:
            if appliesToModified { criteria.modificationOlderThanDays = staleAgeDays }
            if appliesToAccessed { criteria.accessOlderThanDays = staleAgeDays }
        case .date:
            if appliesToModified { criteria.modificationBeforeDate = staleSinceDate }
            if appliesToAccessed { criteria.accessBeforeDate = staleSinceDate }
        }
    }

    // MARK: - Archive Password Handling

    @Sendable
    private func requestArchivePassword(archiveName: String) async -> ArchivePasswordResponse {
        return await withCheckedContinuation { continuation in
            Task { @MainActor [weak self] in
                guard let self else {
                    continuation.resume(returning: .skip)
                    return
                }
                self.passwordArchiveName = archiveName
                self.archivePassword = ""
                self.passwordContinuation = continuation
                self.showPasswordDialog = true
            }
        }
    }

    /// Called from UI when user provides archive password
    func submitArchivePassword() {
        let pwd = archivePassword
        showPasswordDialog = false
        passwordContinuation?.resume(returning: .password(pwd))
        passwordContinuation = nil
    }

    /// Called from UI when user skips password-protected archive
    func skipArchive() {
        showPasswordDialog = false
        passwordContinuation?.resume(returning: .skip)
        passwordContinuation = nil
    }

    // MARK: - Persistence

    func saveResults() {
        guard !results.isEmpty else { return }
        do {
            let payload = SavedSearchPayload(summary: lastSearchSummary, results: results)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: Self.savedResultsURL, options: .atomic)
            log.info("[FindFiles] Saved \(results.count) results")
        } catch {
            log.warning("[FindFiles] Save failed: \(error.localizedDescription)")
        }
    }



    func loadSavedResults() {
        guard FileManager.default.fileExists(atPath: Self.savedResultsURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.savedResultsURL)
            let payload = try JSONDecoder().decode(SavedSearchPayload.self, from: data)
            results = payload.results
            lastSearchSummary = payload.summary
            searchState = .completed
            log.info("[FindFiles] Loaded \(results.count) saved results")
        } catch {
            log.warning("[FindFiles] Load failed: \(error.localizedDescription)")
        }
    }



    // MARK: - Archive Progress Helpers

    func showArchiveProgress(for archiveURL: URL) -> (ProgressPanel, ActiveArchiveProcess) {
        let progressPanel = ProgressPanel.shared
        let handle = ActiveArchiveProcess()
        progressPanel.show(
            archiveName: archiveURL.lastPathComponent,
            destinationPath: archiveURL.deletingLastPathComponent().path
        )
        progressPanel.appendLine("Extracting: \(archiveURL.lastPathComponent)")
        return (progressPanel, handle)
    }



    func openArchiveWithProgress(
        _ archiveURL: URL,
        progressPanel: ProgressPanel,
        handle: ActiveArchiveProcess
    ) async throws -> URL {
        try await ArchiveManager.shared.openArchive(
            at: archiveURL,
            onProgress: { line in
                Task { @MainActor in
                    progressPanel.appendLine(line)
                }
            },
            processHandle: handle
        )
    }
}

// MARK: - Saved Search Payload
struct SavedSearchPayload: Codable {
    let summary: String
    let results: [FindFilesResult]
}
