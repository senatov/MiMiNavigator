// CntMenuCoord+FileOps.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ContextMenuCoordinator file operations (delete, rename, duplicate, compress, pack, create folder, links, paste)

import AppKit
import FileModelKit
import Foundation

// MARK: - ContextMenuCoordinator + File Operations
/// Extension containing async file operation executors
extension ContextMenuCoordinator {

    // MARK: - Panel Helpers

    private func oppositePanel(of panel: FavPanelSide) -> FavPanelSide {
        panel == .left ? .right : .left
    }

    private func refreshOppositePanel(of panel: FavPanelSide, appState: AppState) {
        refreshPanel(oppositePanel(of: panel), appState: appState)
    }

    // MARK: - Delete

    private func alignPanelPathAfterRename(panel: FavPanelSide, renamedURL: URL, appState: AppState) {
        let currentPath = appState.url(for: panel).path
        let renamedParentPath = renamedURL.deletingLastPathComponent().path

        if PathUtils.areEqual(currentPath, renamedParentPath) {
            return
        }

        let currentURL = URL(fileURLWithPath: currentPath)
        let resolvedCurrent = resolveSourceURL(currentURL)
        let resolvedParent = resolveSourceURL(renamedURL.deletingLastPathComponent())

        if PathUtils.areEqual(resolvedCurrent.path, resolvedParent.path) {
            log.info("[Rename] aligning panel path after rename: '\(currentPath)' → '\(renamedParentPath)'")
            navigateTo(resolvedParent, panel: panel, appState: appState)
        }
    }

    /// Resolve firmlink paths: /tmp ↔ /private/tmp, /var ↔ /private/var, /etc ↔ /private/etc.
    /// Returns the first existing variant, or the original URL if nothing works.
    func resolveSourceURL(_ url: URL) -> URL {
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let path = url.path
        let firmlinks: [(prefix: String, real: String)] = [
            ("/private/tmp", "/tmp"),
            ("/tmp", "/private/tmp"),
            ("/private/var", "/var"),
            ("/var", "/private/var"),
            ("/private/etc", "/etc"),
            ("/etc", "/private/etc"),
        ]
        for fl in firmlinks where path.hasPrefix(fl.prefix) {
            let alt = fl.real + path.dropFirst(fl.prefix.count)
            if FileManager.default.fileExists(atPath: alt) {
                log.info("[Rename] firmlink resolved: '\(path)' → '\(alt)'")
                return URL(fileURLWithPath: alt)
            }
        }
        log.warning("[Rename] source not found at any firmlink variant: '\(path)'")
        return url
    }

    // MARK: - Duplicate

    /// Duplicate file (Finder-style naming), then select the duplicate
    func performDuplicate(file: CustomFile, appState: AppState) async {
        log.debug("\(#function) file='\(file.nameStr)'")

        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await DuplicateService.shared.duplicate(file: file.urlValue)
            let panel = panelForPath(file.urlValue.deletingLastPathComponent().path, appState: appState)
            log.info("\(#function) SUCCESS created '\(result.lastPathComponent)' → selecting on \(panel)")
            await appState.refreshAndSelect(name: result.lastPathComponent, on: panel)
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Duplicate Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Compress

    func performCompress(
        files: [CustomFile],
        archiveName: String,
        destination: URL,
        moveToArchive: Bool,
        compressionLevel: CompressionLevel = .normal,
        password: String? = nil,
        appState: AppState
    ) async {
        log.debug(
            "\(#function) files.count=\(files.count) archiveName='\(archiveName)' dest='\(destination.path)' moveToArchive=\(moveToArchive) level=\(compressionLevel) hasPassword=\(password != nil)"
        )

        isProcessing = true
        defer { isProcessing = false }

        do {
            let urls = files.map { $0.urlValue }

            let result = try await CompressService.shared.compress(
                files: urls,
                archiveName: archiveName,
                destination: destination,
                moveToArchive: moveToArchive,
                compressionLevel: compressionLevel,
                password: password
            )

            refreshPanels(appState: appState)

            log.info("\(#function) SUCCESS created '\(result.lastPathComponent)' moveToArchive=\(moveToArchive)")

            // Show yellow HUD popup
            ArchiveInfoPopupController.shared.showArchiveCreated(
                archiveName: result.lastPathComponent,
                destination: destination,
                fileCount: files.count,
                format: .zip,  // CompressService always creates ZIP
                compressionLevel: compressionLevel,
                encrypted: password != nil && !password!.isEmpty
            )
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Compress Failed", message: error.localizedDescription)
        }
    }

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
}
