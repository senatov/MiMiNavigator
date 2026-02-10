// FindFilesViewModel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ViewModel for the Find Files panel — bridges UI with FindFilesEngine

import AppKit
import Foundation
import SwiftUI

// MARK: - Search State
enum FindFilesState: Equatable {
    case idle
    case searching
    case paused
    case completed
    case cancelled
}

// MARK: - Find Files ViewModel
@MainActor
@Observable
final class FindFilesViewModel {

    // MARK: - Search Parameters (bound to UI)
    var fileNamePattern: String = "*.*"
    var searchText: String = ""
    var searchDirectory: String = ""
    var caseSensitive: Bool = false
    var useRegex: Bool = false
    var searchInSubdirectories: Bool = true
    var searchInArchives: Bool = false

    // Size filter
    var useSizeFilter: Bool = false
    var fileSizeMin: String = ""
    var fileSizeMax: String = ""

    // Date filter
    var useDateFilter: Bool = false
    var dateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var dateTo: Date = Date()

    // MARK: - Results & State
    var results: [FindFilesResult] = []
    var searchState: FindFilesState = .idle
    var stats: FindFilesStats = FindFilesStats()
    var selectedResult: FindFilesResult?
    var errorMessage: String?

    // MARK: - Archive Password Dialog
    var showPasswordDialog: Bool = false
    var passwordArchiveName: String = ""
    var archivePassword: String = ""
    var passwordContinuation: CheckedContinuation<ArchivePasswordResponse, Never>?

    // MARK: - Engine
    private let engine = FindFilesEngine()
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize with search directory from active panel
    func configure(searchPath: String) {
        if searchDirectory.isEmpty {
            searchDirectory = searchPath
        }
    }

    // MARK: - Start Search

    func startSearch() {
        guard searchState != .searching else { return }

        log.info("[FindFiles] Starting search: name='\(fileNamePattern)' text='\(searchText)' dir='\(searchDirectory)'")

        // Validate directory
        let dirURL = URL(fileURLWithPath: searchDirectory)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue else {
            errorMessage = "Directory not found: \(searchDirectory)"
            return
        }

        // Clear previous results
        results.removeAll()
        errorMessage = nil
        searchState = .searching

        // Build criteria
        var criteria = FindFilesCriteria(searchDirectory: dirURL)
        criteria.fileNamePattern = fileNamePattern.isEmpty ? "*" : fileNamePattern
        criteria.searchText = searchText
        criteria.caseSensitive = caseSensitive
        criteria.useRegex = useRegex
        criteria.searchInSubdirectories = searchInSubdirectories
        criteria.searchInArchives = searchInArchives

        if useSizeFilter {
            criteria.fileSizeMin = Int64(fileSizeMin)
            criteria.fileSizeMax = Int64(fileSizeMax)
        }
        if useDateFilter {
            criteria.dateFrom = dateFrom
            criteria.dateTo = dateTo
        }

        // Start async search
        searchTask = Task { [weak self] in
            guard let self else { return }

            let stream = await engine.search(
                criteria: criteria,
                passwordCallback: { [weak self] archiveName in
                    guard let self else { return .skip }
                    return await self.requestArchivePassword(archiveName: archiveName)
                }
            )

            for await result in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.results.append(result)
                }
                // Update stats periodically
                if self.results.count % 10 == 0 {
                    let currentStats = await engine.getStats()
                    await MainActor.run {
                        self.stats = currentStats
                    }
                }
            }

            let finalStats = await engine.getStats()
            await MainActor.run {
                self.stats = finalStats
                if Task.isCancelled {
                    self.searchState = .cancelled
                } else {
                    self.searchState = .completed
                }
                log.info("[FindFiles] Search finished: \(self.results.count) results, \(self.stats.formattedElapsed)")
            }
        }
    }

    // MARK: - Cancel Search

    func cancelSearch() {
        log.info("[FindFiles] Cancelling search")
        searchTask?.cancel()
        searchTask = nil
        Task {
            await engine.cancel()
        }
        searchState = .cancelled
    }

    // MARK: - New Search (reset)

    func newSearch() {
        cancelSearch()
        results.removeAll()
        searchState = .idle
        errorMessage = nil
        stats = FindFilesStats()
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

    // MARK: - Actions on Results

    /// Navigate to result file in the active panel
    func goToFile(result: FindFilesResult, appState: AppState) {
        let targetDir = result.fileURL.deletingLastPathComponent().path
        let panel = appState.focusedPanel
        appState.updatePath(targetDir, for: panel)
        Task {
            await appState.scanner.refreshFiles(currSide: panel)
            // Try to select the file
            let files = appState.displayedFiles(for: panel)
            if let match = files.first(where: { $0.nameStr == result.fileName }) {
                appState.select(match, on: panel)
            }
        }
    }

    /// Open the result file in default application
    func openFile(result: FindFilesResult) {
        if result.isInsideArchive {
            // For archive entries — open the archive itself
            if let archivePath = result.archivePath {
                NSWorkspace.shared.open(URL(fileURLWithPath: archivePath))
            }
        } else {
            NSWorkspace.shared.open(result.fileURL)
        }
    }

    /// Reveal the result file in Finder
    func revealInFinder(result: FindFilesResult) {
        if result.isInsideArchive, let archivePath = result.archivePath {
            NSWorkspace.shared.selectFile(archivePath, inFileViewerRootedAtPath: "")
        } else {
            NSWorkspace.shared.selectFile(result.filePath, inFileViewerRootedAtPath: "")
        }
    }

    /// Copy result paths to clipboard
    func copyResultPaths() {
        let paths = results.map(\.filePath).joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths, forType: .string)
    }

    /// Export results to file
    func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "search_results.txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let content = self.results.map { result in
                var line = result.filePath
                if let context = result.matchContext, let lineNum = result.lineNumber {
                    line += ":\(lineNum): \(context)"
                }
                if result.isInsideArchive, let archive = result.archivePath {
                    line = "[\(archive)] \(line)"
                }
                return line
            }.joined(separator: "\n")
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
