// FindFilesViewModel+Actions.swift
// MiMiNavigator
//
// Extracted from FindFilesViewModel.swift
// Copyright © 2026 Senatov. All rights reserved.
// Description: Result actions — go to file, open, reveal, export, show in panel

import AppKit
import FileModelKit
import Foundation

// MARK: - Actions on Results
extension FindFilesViewModel {

    /// Navigate to result file in the active panel.
    func goToFile(result: FindFilesResult, appState: AppState) {
        let panel = appState.focusedPanel
        if result.isInsideArchive, let archivePath = result.archivePath {
            goToArchiveResult(result: result, archivePath: archivePath, panel: panel, appState: appState)
        } else {
            goToRegularResult(result: result, panel: panel, appState: appState)
        }
    }

    /// Open the result file in default application
    func openFile(result: FindFilesResult) {        if result.isInsideArchive, let archivePath = result.archivePath {
            NSWorkspace.shared.open(URL(fileURLWithPath: archivePath))
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
        panel.begin { response in            guard response == .OK, let url = panel.url else { return }
            let content = self.buildExportContent()
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }



    // MARK: - Show in Panel

    /// Convert search results to CustomFile list and inject into the focused panel.
    func showInPanel(appState: AppState) {
        guard !results.isEmpty else { return }
        let panel = appState.focusedPanel
        let capturedResults = results
        Task { @MainActor in
            let (customFiles, openedArchives) = await buildCustomFiles(from: capturedResults, appState: appState, panel: panel)
            appState.searchResultArchives[panel] = openedArchives
            appState.showSearchResults(customFiles, virtualPath: "\u{1F50D} Search Results", on: panel)
            log.info("[FindFiles] showInPanel: \(customFiles.count) files (\(openedArchives.count) archives)")
        }
    }



    // MARK: - Private Helpers

    private func goToRegularResult(result: FindFilesResult, panel: FavPanelSide, appState: AppState) {
        let targetDir = result.fileURL.deletingLastPathComponent().path
        Task { @MainActor in
            await refreshPanel(at: targetDir, panel: panel, appState: appState)
            selectFile(named: result.fileName, panel: panel, appState: appState)
        }
    }
    private func goToArchiveResult(result: FindFilesResult, archivePath: String, panel: FavPanelSide, appState: AppState) {
        let archiveURL = URL(fileURLWithPath: archivePath)
        Task { @MainActor in
            log.info("[FindFiles] goToFile: extracting \(archiveURL.lastPathComponent)")
            let (progressPanel, handle) = showArchiveProgress(for: archiveURL)
            do {
                let tempDir = try await openArchiveWithProgress(archiveURL, progressPanel: progressPanel, handle: handle)
                progressPanel.finish(success: true)
                var archState = appState.archiveState(for: panel)
                archState.enterArchive(archiveURL: archiveURL, tempDir: tempDir)
                appState.setArchiveState(archState, for: panel)
                let targetFileURL = archiveTargetFileURL(for: result, archivePath: archivePath, tempDir: tempDir)
                await refreshPanel(at: targetFileURL.deletingLastPathComponent().path, panel: panel, appState: appState)
                selectFile(named: targetFileURL.lastPathComponent, panel: panel, appState: appState)
            } catch {
                progressPanel.finish(success: false, details: error.localizedDescription)
                log.error("[FindFiles] goToFile: extract failed: \(error.localizedDescription)")
                let archiveDirPath = archiveURL.deletingLastPathComponent().path
                await refreshPanel(at: archiveDirPath, panel: panel, appState: appState)
                selectFile(named: archiveURL.lastPathComponent, panel: panel, appState: appState)
            }
        }
    }

    private func selectFile(named fileName: String, panel: FavPanelSide, appState: AppState) {
        let files = appState.displayedFiles(for: panel)
        if let match = files.first(where: { $0.nameStr == fileName }) {
            appState.select(match, on: panel)
        }
    }
    private func refreshPanel(at path: String, panel: FavPanelSide, appState: AppState) async {
        appState.updatePath(path, for: panel)
        if panel == .left {
            await appState.scanner.setLeftDirectory(pathStr: path)
            await appState.scanner.refreshFiles(currSide: .left)
            await appState.refreshLeftFiles()
        } else {
            await appState.scanner.setRightDirectory(pathStr: path)
            await appState.scanner.refreshFiles(currSide: .right)
            await appState.refreshRightFiles()
        }
    }

    private func archiveTargetFileURL(for result: FindFilesResult, archivePath: String, tempDir: URL) -> URL {
        let internalPath = result.fileURL.path
            .replacingOccurrences(of: archivePath, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return tempDir.appendingPathComponent(internalPath)
    }

    func archiveInternalPath(for result: FindFilesResult, archivePath: String) -> String {
        if result.filePath.hasPrefix(archivePath) {
            return String(result.filePath.dropFirst(archivePath.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return result.fileName
    }
    private func buildExportContent() -> String {
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        var lines: [String] = [
            "MiMiNavigator — Search Results",
            "Date: \(dateStr)",
            "Query: \(lastSearchSummary)",
            "Found: \(results.count) file(s)",
            String(repeating: "-", count: 60),
            ""
        ]
        for result in results {
            var line = result.filePath
            if let context = result.matchContext, let lineNum = result.lineNumber {
                line += ":\(lineNum): \(context)"
            }
            if result.isInsideArchive, let archive = result.archivePath {
                line = "[\(archive)] \(line)"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private func buildCustomFiles(
        from capturedResults: [FindFilesResult],
        appState: AppState,
        panel: FavPanelSide
    ) async -> ([CustomFile], Set<String>) {
        var customFiles: [CustomFile] = []
        var openedArchives: Set<String> = []
        var extractedArchiveDirectories: [String: URL] = [:]
        let progressPanel = ProgressPanel.shared
        for result in capturedResults {
            if result.isInsideArchive, let archivePath = result.archivePath {
                let archiveURL = URL(fileURLWithPath: archivePath)
                let tempDir: URL
                if let existingTempDir = extractedArchiveDirectories[archivePath] {
                    tempDir = existingTempDir
                } else {
                    do {
                        let (panelView, handle) = showArchiveProgress(for: archiveURL)
                        tempDir = try await openArchiveWithProgress(archiveURL, progressPanel: panelView, handle: handle)
                        panelView.finish(success: true)
                        extractedArchiveDirectories[archivePath] = tempDir
                        openedArchives.insert(archivePath)
                    } catch {
                        progressPanel.finish(success: false, details: error.localizedDescription)
                        log.error("[FindFiles] showInPanel: archive extract failed: \(error.localizedDescription)")
                        appendUniqueCustomFile(name: result.fileName, path: archivePath, to: &customFiles)
                        continue
                    }
                }
                let internalPath = archiveInternalPath(for: result, archivePath: archivePath)
                let extractedURL = tempDir.appendingPathComponent(internalPath)
                if FileManager.default.fileExists(atPath: extractedURL.path) {
                    customFiles.append(CustomFile(extractedPath: extractedURL.path, archiveSourcePath: archivePath, archiveInternalPath: internalPath))
                } else {
                    log.warning("[FindFiles] showInPanel: extracted file not found: \(extractedURL.path)")
                    appendUniqueCustomFile(name: result.fileName, path: archivePath, to: &customFiles)
                }
            } else {
                customFiles.append(CustomFile(name: result.fileName, path: result.filePath))
            }
        }
        return (customFiles, openedArchives)
    }

    private func appendUniqueCustomFile(name: String, path: String, to files: inout [CustomFile]) {
        let cf = CustomFile(name: name, path: path)
        if !files.contains(where: { $0.id == cf.id }) {
            files.append(cf)
        }
    }
}
