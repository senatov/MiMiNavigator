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

    private func resolvedActivationTarget(for file: CustomFile) -> (url: URL, isDirectory: Bool)? {
        let originalURL = file.urlValue

        guard originalURL.isFileURL else {
            return (originalURL, file.isDirectory)
        }

        if let aliasTarget = tryResolveAliasTarget(for: originalURL, file: file) {
            return aliasTarget
        }

        if let symlinkTarget = resolveSymlinkTarget(for: originalURL, file: file) {
            return symlinkTarget
        }

        return (originalURL, file.isDirectory)
    }



    private func tryResolveAliasTarget(for url: URL, file: CustomFile) -> (url: URL, isDirectory: Bool)? {
        guard shouldTryAliasResolution(for: url, file: file) else {
            return nil
        }

        guard let resolvedURL = try? URL(resolvingAliasFileAt: url, options: [.withoutUI]) else {
            if file.isAlias {
                log.warning("[Activate] failed to resolve alias '\(file.nameStr)': \(file.pathStr)")
            }
            return nil
        }

        var aliasDirFlag = ObjCBool(false)
        let isDirectory = FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &aliasDirFlag) && aliasDirFlag.boolValue
        return (resolvedURL, isDirectory)
    }




    private func resolveSymlinkTarget(for url: URL, file: CustomFile) -> (url: URL, isDirectory: Bool)? {
        guard file.isSymbolicLink || file.isSymbolicDirectory else {
            return nil
        }

        // resolvingSymlinksInPath() fails on macOS firmlinks (/var, /tmp, /etc)
        // — returns the same URL and resourceValues reports isDirectory=false.
        // FileManager.fileExists resolves symlinks/firmlinks correctly.
        let path = url.path
        var isDirFlag = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirFlag)
        if exists, isDirFlag.boolValue {
            return (url, true)
        }

        let resolvedURL = url.resolvingSymlinksInPath()
        var resolvedDirFlag = ObjCBool(false)
        let isDir = FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &resolvedDirFlag) && resolvedDirFlag.boolValue
        return (resolvedURL, isDir)
    }




    private func shouldTryAliasResolution(for url: URL, file: CustomFile) -> Bool {
        if file.isAlias {
            return true
        }

        if file.isDirectory || file.isSymbolicLink || file.isSymbolicDirectory {
            return false
        }

        if let values = try? url.resourceValues(forKeys: [.isAliasFileKey]), values.isAliasFile == true {
            return true
        }

        if let fileType = try? url.resourceValues(forKeys: [.fileResourceTypeKey]).fileResourceType,
           fileType == .regular {
            return true
        }

        return false
    }

    private func activateResolvedDirectory(_ resolvedURL: URL, originalFile: CustomFile, on panel: FavPanelSide) {
        let pathToOpen = resolvedURL.isFileURL ? resolvedURL.path : resolvedURL.absoluteString

        log.info("[Activate] navigate directory '\(originalFile.nameStr)' -> \(pathToOpen)")

        if !resolvedURL.isFileURL {
            Task { @MainActor in
                await navigateToDirectory(pathToOpen, on: panel)
            }
            return
        }

        // resourceValues(.isDirectoryKey) lies about firmlinks (/var, /tmp, /etc).
        // FileManager.fileExists resolves symlinks/firmlinks correctly.
        var isDirFlag = ObjCBool(false)
        let isDirectory = FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirFlag) && isDirFlag.boolValue
        guard isDirectory else {
            if originalFile.isAlias {
                log.warning("[Activate] alias target is not a directory: \(pathToOpen)")
            } else if originalFile.isSymbolicLink || originalFile.isSymbolicDirectory {
                log.warning("[Activate] symlink target is not a directory: \(pathToOpen)")
            } else {
                log.warning("[Activate] target is not a directory: \(pathToOpen)")
            }
            return
        }

        Task { @MainActor in
            await navigateToDirectory(pathToOpen, on: panel)
        }
    }

    func selectionCopy() { fileActions?.copyToOppositePanel() }
    func openSelectedItem() { fileActions?.openSelectedItem() }

    // MARK: - Activate item (double-click / Enter)
    func activateItem(_ file: CustomFile, on panel: FavPanelSide) {
        let resolvedTarget = resolvedActivationTarget(for: file)

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
        if let resolvedTarget, resolvedTarget.isDirectory {
            activateResolvedDirectory(resolvedTarget.url, originalFile: file, on: panel)
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
        let openURL = resolvedTarget?.url ?? file.urlValue

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(openURL, configuration: configuration) { _, error in
            if let error { log.error("[AppState] open file failed: \(error.localizedDescription)") }
        }
    }

    func revealLogFileInFinder() { FinderIntegration.revealLogFile() }
}
