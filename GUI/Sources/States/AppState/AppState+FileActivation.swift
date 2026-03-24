    // AppState+FileActivation.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 15.03.2026.
    // Copyright © 2025-2026 Senatov. All rights reserved.
    // Description: File activation — open, enter directory, enter archive, launch app

    import AppKit
    import FileModelKit
    import Foundation

    // MARK: - File Activation
    extension AppState {

        func selectionCopy() { fileActions?.copyToOppositePanel() }
        func openSelectedItem() { fileActions?.openSelectedItem() }

        // MARK: - Activate item (double-click / Enter)
        func activateItem(_ file: CustomFile, on panel: FavPanelSide) {
            if ParentDirectoryEntry.isParentEntry(file) {
                Task { await navigateToParent(on: panel) }
                return
            }
            if !file.isDirectory && ArchiveExtensions.isArchive(file.fileExtension) {
                Task { await enterArchive(at: file.urlValue, on: panel) }
                return
            }
            let ext = file.fileExtension.lowercased()
            if ext == "app" {
                NSWorkspace.shared.openApplication(at: file.urlValue, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if let error { log.error("[AppState] launch app failed: \(error.localizedDescription)") }
                }
                return
            }
            if file.isDirectory || file.isSymbolicDirectory {

                // --- Remote directory handling ---
                if !file.urlValue.isFileURL {
                    log.info("[AppState] activateItem: remote directory '\(file.urlValue.absoluteString)'")
                    Task { @MainActor in
                        await navigateToDirectory(file.urlValue.absoluteString, on: panel)
                    }
                    return
                }

                // --- Local directory handling ---
                let resolvedURL = file.urlValue.resolvingSymlinksInPath()
                let newPath = resolvedURL.path
                var isDir: ObjCBool = false

                guard FileManager.default.fileExists(atPath: newPath, isDirectory: &isDir),
                      isDir.boolValue else {
                    log.warning("[AppState] activateItem: broken symlink: \(newPath)")
                    return
                }

                Task { @MainActor in
                    await navigateToDirectory(newPath, on: panel)
                }
                return
            }
            // --- Remote file: download to tmp, open locally ---
            let panelURL = url(for: panel)
            if AppState.isRemotePath(panelURL) {
                let remotePath = file.pathStr
                log.info("[AppState] activateItem: remote file '\(remotePath)' — downloading to tmp")
                Task {
                    do {
                        let localURL = try await RemoteConnectionManager.shared.downloadFile(remotePath: remotePath)
                        _ = await MainActor.run {
                            NSWorkspace.shared.open(localURL)
                        }
                    } catch {
                        log.error("[AppState] remote download failed '\(remotePath)': \(error.localizedDescription)")
                    }
                }
                return
            }

            NSWorkspace.shared.open(
                [file.urlValue],
                withApplicationAt: NSWorkspace.shared.urlForApplication(toOpen: file.urlValue)
                    ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error { log.error("[AppState] open file failed: \(error.localizedDescription)") }
            }
        }

        func revealLogFileInFinder() { FinderIntegration.revealLogFile() }
    }
