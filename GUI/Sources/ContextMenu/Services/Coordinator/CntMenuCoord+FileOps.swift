    // FileOperationExecutors.swift
    // MiMiNavigator
    //
    // Created by Claude AI on 04.02.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Extension of ContextMenuCoordinator that implements file operation executors (delete, rename, duplicate, compress, pack, etc.)

    import AppKit
    import FileModelKit
    import Foundation

    // MARK: - ContextMenuCoordinator + File Operations
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
                // Mark archives dirty when deleting files from archive search results
                for file in files where file.isFromArchiveSearch {
                    await ArchiveManager.shared.markDirtyByTempPath(file.pathStr)
                    log.info("\(#function) marked archive dirty after deleting: \(file.nameStr)")
                }
                let panel = panelForPath(files.first!.urlValue.deletingLastPathComponent().path, appState: appState)
                await appState.refreshAndSelectAfterRemoval(removedFiles: files, on: panel)
                // Also refresh opposite panel in case it shows the same directory
                let otherPanel: PanelSide = panel == .left ? .right : .left
                refreshPanel(otherPanel, appState: appState)
                log.info("\(#function) SUCCESS deleted \(files.count) item(s) → cursor moved to next file on \(panel)")
            } catch {
                log.error("\(#function) FAILED: \(error.localizedDescription)")
                activeDialog = .error(title: "Delete Failed", message: error.localizedDescription)
            }
        }

        // MARK: - Rename

        /// Rename file or directory, then select the renamed item
        func performRename(file: CustomFile, newName: String, panel: PanelSide, appState: AppState) async {
            log.info("[Rename] 🏁 START: '\(file.nameStr)' → '\(newName)' path='\(file.urlValue.path)' panel=\(panel)")

            isProcessing = true
            defer {
                isProcessing = false
                activeDialog = nil
            }

            do {
                let oldURL = resolveSourceURL(file.urlValue)
                let newURL = try await fileOps.renameFile(oldURL, to: newName)
                let exists = FileManager.default.fileExists(atPath: newURL.path)
                log.info("[Rename] ✅ FileManager.moveItem done: newURL='\(newURL.path)' exists=\(exists)")
                if file.isFromArchiveSearch {
                    await ArchiveManager.shared.markDirtyByTempPath(file.pathStr)
                    log.info("[Rename] marked archive dirty after renaming: \(file.nameStr)")
                }
                log.info("[Rename] panel=\(panel) → refreshAndSelect('\(newName)')")
                await appState.refreshAndSelect(name: newName, on: panel)
                let otherPanel: PanelSide = panel == .left ? .right : .left
                refreshPanel(otherPanel, appState: appState)
                log.info("[Rename] 🏁 END SUCCESS")
            } catch {
                log.error("[Rename] ❌ FAILED: \(error.localizedDescription)")
                activeDialog = .error(title: "Rename Failed", message: error.localizedDescription)
            }
        }

        /// Resolve firmlink paths: /tmp ↔ /private/tmp, /var ↔ /private/var, /etc ↔ /private/etc.
        /// Returns the first existing variant, or the original URL if nothing works.
        private func resolveSourceURL(_ url: URL) -> URL {
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
            appState: AppState
        ) async {
            log.debug("\(#function) files.count=\(files.count) archiveName='\(archiveName)' dest='\(destination.path)' moveToArchive=\(moveToArchive)")

            isProcessing = true
            defer { isProcessing = false }

            do {
                let urls = files.map { $0.urlValue }

                let result = try await CompressService.shared.compress(
                    files: urls,
                    archiveName: archiveName,
                    destination: destination,
                    moveToArchive: moveToArchive
                )

                refreshPanels(appState: appState)

                log.info("\(#function) SUCCESS created '\(result.lastPathComponent)' moveToArchive=\(moveToArchive)")
            } catch {
                log.error("\(#function) FAILED: \(error.localizedDescription)")
                activeDialog = .error(title: "Compress Failed", message: error.localizedDescription)
            }
        }

        // MARK: - Pack (Archive with options)
        /// Pack files into archive with custom options.
        /// Creates destination directory if it doesn't exist.
        /// Selects the created archive in the appropriate panel.
        func performPack(
            files: [CustomFile], archiveName: String, format: ArchiveFormat, destination: URL, deleteSource: Bool = false,
            appState: AppState
        ) async {
            log.debug(
                "\(#function) files.count=\(files.count) archiveName='\(archiveName)' format=\(format) dest='\(destination.path)' deleteSource=\(deleteSource)"
            )

            isProcessing = true
            defer {
                isProcessing = false
                activeDialog = nil
            }

            do {
                // Create destination directory if it doesn't exist
                if !FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    log.info("\(#function) created destination directory: '\(destination.path)'")
                }

                let urls = files.map { $0.urlValue }
                let archiveURL = try await archiveService.createArchive(
                    from: urls,
                    to: destination,
                    archiveName: archiveName,
                    format: format
                )

                // Delete source files if requested
                if deleteSource {
                    for url in urls {
                        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                        log.info("\(#function) trashed source: '\(url.lastPathComponent)'")
                    }
                }

                // Determine which panel shows the destination and navigate+select
                let archiveName = archiveURL.lastPathComponent
                let destPath = destination.path
                let panel = panelForPath(destPath, appState: appState)

                // If destination is the current directory of a panel, refresh and select
                if PathUtils.areEqual(appState.leftPath, destPath) || PathUtils.areEqual(appState.rightPath, destPath) {
                    await appState.refreshAndSelect(name: archiveName, on: panel)
                } else {
                    // Destination is a different directory — navigate to it, then select
                    navigateTo(destination, panel: panel, appState: appState)
                    // Small delay to let navigation + refresh complete
                    try? await Task.sleep(for: .milliseconds(300))
                    appState.selectFileByName(archiveName, on: panel)
                }

                // Also refresh the other panel (source files may have been deleted)
                let otherPanel: PanelSide = panel == .left ? .right : .left
                refreshPanel(otherPanel, appState: appState)

                log.info("\(#function) SUCCESS created '\(archiveName)' → selected on \(panel)")
                activeDialog = .success(
                    title: "Archive Created",
                    message: "Created: \(archiveName)"
                )
            } catch {
                log.error("\(#function) FAILED: \(error.localizedDescription)")
                activeDialog = .error(title: "Pack Failed", message: error.localizedDescription)
            }
        }

        // MARK: - Create Folder

        /// Create new folder, then select it in the panel
        func performCreateFolder(name: String, at parentURL: URL, appState: AppState) async {
            log.debug("\(#function) name='\(name)' at='\(parentURL.path)'")

            isProcessing = true
            defer {
                isProcessing = false
                activeDialog = nil
            }

            let folderURL = parentURL.appendingPathComponent(name)
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
                let panel = panelForPath(parentURL.path, appState: appState)
                await appState.refreshAndSelect(name: name, on: panel)
                let otherPanel: PanelSide = panel == .left ? .right : .left
                refreshPanel(otherPanel, appState: appState)
                log.info("\(#function) SUCCESS created '\(name)' → selected on \(panel)")
            } catch {
                log.error("\(#function) FAILED: \(error.localizedDescription)")
                activeDialog = .error(title: L10n.Error.failedToCreateFolder, message: error.localizedDescription)
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
