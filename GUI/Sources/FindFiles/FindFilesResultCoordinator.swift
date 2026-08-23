// FindFilesResultCoordinator.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Navigation and panel-result orchestration for Find Files.

import FileModelKit
import FindFilesKit
import Foundation

// MARK: - Find Files Panel Content
struct FindFilesPanelContent {
    let files: [CustomFile]
    let openedArchives: Set<String>
}

// MARK: - Find Files Result Coordinator
@MainActor
final class FindFilesResultCoordinator {
    // MARK: - Navigate
    func navigate(to result: FindFilesResult, appState: AppState) async {
        let panel = appState.focusedPanel
        guard result.isInsideArchive, let archivePath = result.archivePath else {
            await navigate(to: result.fileURL.deletingLastPathComponent().path, selecting: result.fileName, panel: panel, appState: appState)
            return
        }
        let archiveURL = URL(fileURLWithPath: archivePath)
        do {
            let tempDirectory = try await FindFilesArchiveExtractor.extract(archiveURL)
            var archiveState = appState.archiveState(for: panel)
            archiveState.enterArchive(archiveURL: archiveURL, tempDir: tempDirectory)
            appState.setArchiveState(archiveState, for: panel)
            let targetURL = tempDirectory.appendingPathComponent(Self.internalPath(for: result, archivePath: archivePath))
            await navigate(to: targetURL.deletingLastPathComponent().path, selecting: targetURL.lastPathComponent, panel: panel, appState: appState)
        } catch {
            log.error("[FindFiles] archive navigation failed: \(error.localizedDescription)")
            await navigate(to: archiveURL.deletingLastPathComponent().path, selecting: archiveURL.lastPathComponent, panel: panel, appState: appState)
        }
    }

    // MARK: - Build Panel Content
    func buildPanelContent(from results: [FindFilesResult]) async -> FindFilesPanelContent {
        var files: [CustomFile] = []
        var openedArchives: Set<String> = []
        var extractedDirectories: [String: URL] = [:]
        for result in results {
            guard result.isInsideArchive, let archivePath = result.archivePath else {
                files.append(CustomFile(name: result.fileName, path: result.filePath))
                continue
            }
            let archiveURL = URL(fileURLWithPath: archivePath)
            let tempDirectory: URL
            if let existing = extractedDirectories[archivePath] {
                tempDirectory = existing
            } else {
                do {
                    tempDirectory = try await FindFilesArchiveExtractor.extract(archiveURL)
                    extractedDirectories[archivePath] = tempDirectory
                    openedArchives.insert(archivePath)
                } catch {
                    log.error("[FindFiles] panel archive extraction failed: \(error.localizedDescription)")
                    appendUniqueFallback(name: result.fileName, archivePath: archivePath, to: &files)
                    continue
                }
            }
            let internalPath = Self.internalPath(for: result, archivePath: archivePath)
            let extractedURL = tempDirectory.appendingPathComponent(internalPath)
            guard FileManager.default.fileExists(atPath: extractedURL.path) else {
                log.warning("[FindFiles] extracted result missing: \(extractedURL.path)")
                appendUniqueFallback(name: result.fileName, archivePath: archivePath, to: &files)
                continue
            }
            files.append(CustomFile(extractedPath: extractedURL.path, archiveSourcePath: archivePath, archiveInternalPath: internalPath))
        }
        return FindFilesPanelContent(files: files, openedArchives: openedArchives)
    }

    private func navigate(to path: String, selecting name: String, panel: FavPanelSide, appState: AppState) async {
        await appState.navigateToDirectory(path, on: panel)
        if let file = appState.displayedFiles(for: panel).first(where: { $0.nameStr == name }) {
            appState.select(file, on: panel)
        }
    }

    private func appendUniqueFallback(name: String, archivePath: String, to files: inout [CustomFile]) {
        let file = CustomFile(name: name, path: archivePath)
        if !files.contains(where: { $0.id == file.id }) { files.append(file) }
    }

    private static func internalPath(for result: FindFilesResult, archivePath: String) -> String {
        guard result.filePath.hasPrefix(archivePath) else { return result.fileName }
        return String(result.filePath.dropFirst(archivePath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
