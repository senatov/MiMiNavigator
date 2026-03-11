    // AppState+Refresh.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 11.03.2026.
    // Copyright © 2025-2026 Senatov. All rights reserved.
    // Description: Panel refresh operations, remote file listing, path updates

    import FileModelKit
    import Foundation

    // MARK: - Refresh Operations
    extension AppState {

        @Sendable
        func refreshFiles() async {
            await refreshLeftFiles()
            await refreshRightFiles()
        }

        func refreshLeftFiles() async {
            if Self.isRemotePath(leftURL) {
                await refreshRemoteFiles(for: .left)
            } else {
                await scanner.refreshFiles(currSide: .left)
            }
            if selectedLeftFile == nil {
                selectedLeftFile = firstRealFile(in: displayedLeftFiles)
                if let f = selectedLeftFile {
                    log.debug("[AppState] 👆 \(f.nameStr) selected (left)")
                }
            }
        }

        func refreshRightFiles() async {
            if Self.isRemotePath(rightURL) {
                await refreshRemoteFiles(for: .right)
            } else {
                await scanner.refreshFiles(currSide: .right)
            }
            if selectedRightFile == nil {
                selectedRightFile = firstRealFile(in: displayedRightFiles)
                if let f = selectedRightFile {
                    log.debug("[AppState] 👆 \(f.nameStr) selected (right)")
                }
            }
        }
    }

    // MARK: - Remote Path Detection & Refresh
    extension AppState {

        /// Returns true if the URL belongs to an active remote connection
        nonisolated static func isRemotePath(_ url: URL) -> Bool {
            let path = url.absoluteString
            return path.hasPrefix("sftp://")
                || path.hasPrefix("ftp://")
                || path.hasPrefix("/sftp:")
                || path.hasPrefix("/ftp:")
        }

        /// Fetch remote directory listing and populate panel files
        func refreshRemoteFiles(for panel: PanelSide) async {
            let manager = RemoteConnectionManager.shared
            guard let conn = manager.activeConnection else {
                log.error("[AppState] refreshRemoteFiles — no active connection")
                return
            }

            do {
                let remotePath = conn.currentPath
                log.info("[AppState] refreshRemoteFiles panel=\(panel) path=\(remotePath)")

                let items = try await manager.listDirectory(remotePath)
                let files = items.map { CustomFile(remoteItem: $0) }
                let sorted = applySorting(files)

                switch panel {
                case .left:
                    displayedLeftFiles = sorted
                    if selectedLeftFile == nil {
                        selectedLeftFile = firstRealFile(in: sorted)
                    }

                case .right:
                    displayedRightFiles = sorted
                    if selectedRightFile == nil {
                        selectedRightFile = firstRealFile(in: sorted)
                    }
                }

            } catch {
                log.error("[AppState] remote listing failed: \(error.localizedDescription)")
            }
        }
    }



    /// MARK: - Path Updates
    extension AppState {

        func updatePath(_ newURL: URL, for panelSide: PanelSide) {
            let currentURL = url(for: panelSide)
            guard !PathUtils.areEqual(currentURL, newURL) else { return }

            // Prevent files from being used as panel directories
            var normalizedURL = newURL
            var isDirForFileCheck: ObjCBool = false

            if FileManager.default.fileExists(atPath: newURL.path, isDirectory: &isDirForFileCheck),
               !isDirForFileCheck.boolValue {
                normalizedURL = newURL.deletingLastPathComponent()
                log.debug("[AppState] updatePath: file detected, using parent directory → \(normalizedURL.path)")
            }

            log.debug("[AppState] updatePath \(panelSide) → \(normalizedURL.path)")
            focusedPanel = panelSide

            tabManager(for: panelSide).updateActiveTabPath(normalizedURL)

            if !isNavigatingFromHistory {

                // Only directories belong in Navigation History
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: normalizedURL.path, isDirectory: &isDir),
                   isDir.boolValue {
                    navigationHistory(for: panelSide).navigateTo(normalizedURL)
                }

                // Selections history may contain files
                selectionsHistory.setCurrent(to: normalizedURL)
            }

            switch panelSide {

            case .left:

                if Self.isRemotePath(normalizedURL) && !Self.isRemotePath(leftURL) {
                    savedLocalLeftURL = leftURL
                }

                leftURL = normalizedURL
                selectedLeftFile = firstRealFile(in: displayedLeftFiles)

            case .right:

                if Self.isRemotePath(normalizedURL) && !Self.isRemotePath(rightURL) {
                    savedLocalRightURL = rightURL
                }

                rightURL = normalizedURL
                selectedRightFile = firstRealFile(in: displayedRightFiles)
            }
        }

        /// Restore panel to saved local path after remote disconnect
        func restoreLocalPath(for panel: PanelSide) async {

            let savedURL: URL?
            switch panel {
            case .left:  savedURL = savedLocalLeftURL
            case .right: savedURL = savedLocalRightURL
            }

            guard let localURL = savedURL else {
                log.warning("[AppState] no saved local path for \(panel)")
                return
            }

            log.info("[AppState] restoring local path \(panel): \(localURL.path)")

            updatePath(localURL, for: panel)

            if panel == .left {
                await scanner.setLeftDirectory(pathStr: localURL.path)
                await refreshLeftFiles()
            } else {
                await scanner.setRightDirectory(pathStr: localURL.path)
                await refreshRightFiles()
            }
        }
    }
