// FileOperationExecutors.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Executes file operations (delete, rename, duplicate, compress, pack, etc.)

import AppKit
import Foundation

// MARK: - File Operation Executors
/// Extension containing async file operation executors
extension ContextMenuCoordinator {

    // MARK: - Delete

    /// Delete files to trash
    func performDelete(files: [CustomFile], appState: AppState) async {
        log.debug("\(#function) files.count=\(files.count) files=\(files.map { $0.nameStr })")

        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }

        do {
            let urls = files.map { $0.urlValue }
            _ = try await fileOps.deleteFiles(urls)
            refreshPanels(appState: appState)
            log.info("\(#function) SUCCESS deleted \(files.count) item(s)")
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Delete Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Rename

    /// Rename file or directory
    func performRename(file: CustomFile, newName: String, appState: AppState) async {
        log.debug("\(#function) file='\(file.nameStr)' newName='\(newName)'")

        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }

        do {
            _ = try await fileOps.renameFile(file.urlValue, to: newName)
            refreshPanels(appState: appState)
            log.info("\(#function) SUCCESS: '\(file.nameStr)' → '\(newName)'")
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Rename Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Duplicate

    /// Duplicate file (Finder-style naming)
    func performDuplicate(file: CustomFile, appState: AppState) async {
        log.debug("\(#function) file='\(file.nameStr)'")

        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await DuplicateService.shared.duplicate(file: file.urlValue)
            refreshPanels(appState: appState)
            log.info("\(#function) SUCCESS created '\(result.lastPathComponent)'")
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Duplicate Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Compress

    /// Compress files (Finder-style .zip)
    func performCompress(files: [CustomFile], appState: AppState) async {
        log.debug("\(#function) files.count=\(files.count)")

        isProcessing = true
        defer { isProcessing = false }

        do {
            let urls = files.map { $0.urlValue }
            let result = try await CompressService.shared.compress(files: urls)
            refreshPanels(appState: appState)
            log.info("\(#function) SUCCESS created '\(result.lastPathComponent)'")
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Compress Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Pack (Archive with options)

    /// Pack files into archive with custom options
    func performPack(files: [CustomFile], archiveName: String, format: ArchiveFormat, destination: URL, appState: AppState) async {
        log.debug("\(#function) files.count=\(files.count) archiveName='\(archiveName)' format=\(format) dest='\(destination.path)'")

        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }

        do {
            let urls = files.map { $0.urlValue }
            let archiveURL = try await archiveService.createArchive(
                from: urls,
                to: destination,
                archiveName: archiveName,
                format: format
            )
            refreshPanels(appState: appState)
            log.info("\(#function) SUCCESS created '\(archiveURL.lastPathComponent)'")
            activeDialog = .success(
                title: "Archive Created",
                message: "Created: \(archiveURL.lastPathComponent)"
            )
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Pack Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Create Link

    /// Create symbolic link or Finder alias
    func performCreateLink(file: CustomFile, linkName: String, linkType: LinkType, destination: URL, appState: AppState) async {
        log.debug("\(#function) file='\(file.nameStr)' linkName='\(linkName)' type=\(linkType) dest='\(destination.path)'")

        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }

        do {
            switch linkType {
                case .symbolic:
                    _ = try await fileOps.createSymbolicLink(
                        to: file.urlValue,
                        at: destination,
                        linkName: linkName
                    )
                case .alias:
                    try await createFinderAlias(to: file.urlValue, at: destination, name: linkName)
            }
            refreshPanels(appState: appState)
            log.info("\(#function) SUCCESS created link '\(linkName)'")
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Create Link Failed", message: error.localizedDescription)
        }
    }

    /// Create Finder alias (bookmark)
    func createFinderAlias(to source: URL, at destination: URL, name: String) async throws {
        log.debug("\(#function) source='\(source.lastPathComponent)' dest='\(destination.path)' name='\(name)'")

        let aliasURL = destination.appendingPathComponent(name)
        let data = try source.bookmarkData(
            options: .suitableForBookmarkFile,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try URL.writeBookmarkData(data, to: aliasURL)
        log.info("\(#function) SUCCESS created Finder alias '\(aliasURL.lastPathComponent)'")
    }

    // MARK: - Paste

    /// Paste from clipboard
    func performPaste(to panel: PanelSide, appState: AppState) async {
        log.debug("\(#function) panel=\(panel) clipboardHasContent=\(clipboard.hasContent)")

        guard clipboard.hasContent else {
            log.warning("\(#function) clipboard is empty")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let destination = getDestinationPath(for: panel, appState: appState)
        log.debug("\(#function) destination='\(destination.path)'")

        let result = await clipboard.paste(to: destination, coordinator: self)

        switch result {
            case .success(let urls):
                log.info("\(#function) SUCCESS pasted \(urls.count) item(s)")
                refreshPanels(appState: appState)

            case .failure(let error):
                if case FileOperationError.operationCancelled = error {
                    log.info("\(#function) cancelled by user")
                } else {
                    log.error("\(#function) FAILED: \(error.localizedDescription)")
                    activeDialog = .error(title: "Paste Failed", message: error.localizedDescription)
                }
        }
    }
}
