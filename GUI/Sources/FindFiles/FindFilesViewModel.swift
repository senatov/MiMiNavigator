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

    /// Initialize with search directory from active panel.
    /// If selectedFile is an archive, search will be limited to that archive only.
    /// - Parameters:
    ///   - searchPath: Current directory of the active panel
    ///   - selectedFile: Currently selected file (optional)
    func configure(searchPath: String, selectedFile: CustomFile? = nil) {
        // Check if selected file is an archive
        if let file = selectedFile,
           !file.isDirectory,
           isArchiveFile(file) {
            // Selected file is an archive — search only inside this archive
            searchDirectory = file.urlValue.path
            searchInArchives = true
            searchInSubdirectories = true
            log.info("[FindFiles] Configured to search in archive: \(file.nameStr)")
        } else if searchDirectory.isEmpty {
            // Normal case — use panel's current directory
            searchDirectory = searchPath
        }
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

        log.info("[FindFiles] Starting search: name='\(fileNamePattern)' text='\(searchText)' dir='\(searchDirectory)'")

        // Validate target path
        let targetURL = URL(fileURLWithPath: searchDirectory)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir)

        // Check if it's a single archive file to search (not a directory)
        let isArchiveTarget = exists && !isDir.boolValue && ArchiveExtensions.isArchive(targetURL.pathExtension.lowercased())

        guard exists && (isDir.boolValue || isArchiveTarget) else {
            errorMessage = "Path not found: \(searchDirectory)"
            return
        }

        // Save to history
        SearchHistoryManager.shared.add(fileNamePattern, for: .fileNamePattern)
        SearchHistoryManager.shared.add(searchDirectory, for: .searchDirectory)
        if !searchText.isEmpty {
            SearchHistoryManager.shared.add(searchText, for: .searchText)
        }

        // Clear previous results
        results.removeAll()
        errorMessage = nil
        searchState = .searching

        // Build criteria
        var criteria = FindFilesCriteria(searchDirectory: targetURL)
        criteria.fileNamePattern = fileNamePattern.isEmpty ? "*" : fileNamePattern
        criteria.searchText = searchText
        criteria.caseSensitive = caseSensitive
        criteria.useRegex = useRegex
        criteria.searchInSubdirectories = searchInSubdirectories
        criteria.searchInArchives = searchInArchives
        criteria.isArchiveOnlySearch = isArchiveTarget

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
                passwordCallback: { @concurrent [weak self] archiveName in
                    guard let self else { return .skip }
                    return await self.requestArchivePassword(archiveName: archiveName)
                }
            )

            // Batch results to avoid thousands of MainActor dispatches.
            // Flush every 50 results or every 0.15s — whichever comes first.
            var batch: [FindFilesResult] = []
            batch.reserveCapacity(64)
            var lastFlush = ContinuousClock.now
            let flushInterval: Duration = .milliseconds(150)
            let batchSize = 50

            for await result in stream {
                guard !Task.isCancelled else { break }
                batch.append(result)

                let now = ContinuousClock.now
                if batch.count >= batchSize || now - lastFlush >= flushInterval {
                    let chunk = batch
                    batch.removeAll(keepingCapacity: true)
                    lastFlush = now

                    let currentStats = await engine.getStats()
                    self.results.append(contentsOf: chunk)
                    self.stats = currentStats
                }
            }

            // Flush remaining
            if !batch.isEmpty {
                self.results.append(contentsOf: batch)
            }

            let finalStats = await engine.getStats()
            self.stats = finalStats
            if Task.isCancelled {
                self.searchState = .cancelled
            } else {
                self.searchState = .completed
            }
            log.info("[FindFiles] Search finished: \(self.results.count) results, \(self.stats.formattedElapsed)")
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

    /// Navigate to result file in the active panel.
    /// For archive entries: extract the archive first, then navigate into the extracted directory.
    func goToFile(result: FindFilesResult, appState: AppState) {
        let panel = appState.focusedPanel

        if result.isInsideArchive, let archivePath = result.archivePath {
            // Archive result: extract archive and navigate to the file inside it
            let archiveURL = URL(fileURLWithPath: archivePath)

            Task { @MainActor in
                log.info("[FindFiles] goToFile: extracting archive \(archiveURL.lastPathComponent) for result \(result.fileName)")

                do {
                    let tempDir = try await ArchiveManager.shared.openArchive(at: archiveURL)

                    // Update archive state on the panel
                    var archState = appState.archiveState(for: panel)
                    archState.enterArchive(archiveURL: archiveURL, tempDir: tempDir)
                    appState.setArchiveState(archState, for: panel)

                    // result.fileURL is like: /path/to/archive.zip/internal/path/file.txt
                    // Compute the actual path inside the temp dir
                    let internalPath = result.fileURL.path
                        .replacingOccurrences(of: archivePath, with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

                    let targetFileURL = tempDir.appendingPathComponent(internalPath)
                    let targetDir = targetFileURL.deletingLastPathComponent().path
                    let targetFileName = targetFileURL.lastPathComponent

                    appState.updatePath(targetDir, for: panel)

                    if panel == .left {
                        await appState.scanner.setLeftDirectory(pathStr: targetDir)
                        await appState.scanner.refreshFiles(currSide: .left)
                        await appState.refreshLeftFiles()
                    } else {
                        await appState.scanner.setRightDirectory(pathStr: targetDir)
                        await appState.scanner.refreshFiles(currSide: .right)
                        await appState.refreshRightFiles()
                    }

                    // Try to select the target file
                    let files = appState.displayedFiles(for: panel)
                    if let match = files.first(where: { $0.nameStr == targetFileName }) {
                        appState.select(match, on: panel)
                    }

                    log.info("[FindFiles] goToFile: navigated to \(targetDir) and selected \(targetFileName)")
                } catch {
                    log.error("[FindFiles] goToFile: failed to extract archive: \(error.localizedDescription)")
                    // Fallback: reveal the archive in panel
                    let archiveDir = archiveURL.deletingLastPathComponent().path
                    appState.updatePath(archiveDir, for: panel)
                    Task {
                        await appState.scanner.refreshFiles(currSide: panel)
                        let files = appState.displayedFiles(for: panel)
                        if let match = files.first(where: { $0.nameStr == archiveURL.lastPathComponent }) {
                            appState.select(match, on: panel)
                        }
                    }
                }
            }
        } else {
            // Normal file result: navigate to containing directory and select
            let targetDir = result.fileURL.deletingLastPathComponent().path
            appState.updatePath(targetDir, for: panel)
            Task {
                await appState.scanner.refreshFiles(currSide: panel)
                let files = appState.displayedFiles(for: panel)
                if let match = files.first(where: { $0.nameStr == result.fileName }) {
                    appState.select(match, on: panel)
                }
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
