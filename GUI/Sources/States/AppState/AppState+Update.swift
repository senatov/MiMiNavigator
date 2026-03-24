//
//  AppState+Update.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation

// MARK: - Path Updates
extension AppState {

    func updatePath(_ pathString: String, for panel: PanelSide) {
        // remote strings must go through URL(string:) — not fileURLWithPath, that mangles them
        if pathString.hasPrefix("sftp://") || pathString.hasPrefix("ftp://") {
            guard let remoteURL = URL(string: pathString) else {
                log.error("\(#function) bad remote URL string: \(pathString)")
                return
            }
            log.debug("\(#function) remote path detected, using URL(string:) for \(pathString)")
            updatePath(remoteURL, for: panel)
            return
        }
        updatePath(URL(fileURLWithPath: pathString), for: panel)
    }

    func updatePath(_ newURL: URL, for panel: PanelSide) {
        // guard: mangled remote URL wrapped in fileURLWithPath — bail early
        if Self.isRemotePath(newURL) && newURL.scheme == "file" {
            log.warning("\(#function) mangled remote URL detected: \(newURL.absoluteString) — skipping local update")
            return
        }
        let currentURL = url(for: panel)
        guard !PathUtils.areEqual(currentURL, newURL) else { return }

        // fileExists/isDirectory can block on NAS/SMB — run off MainActor, apply result back
        Task {
            let (normalizedURL, isDir) = await Self.resolveURLOffMainActor(newURL)
            await MainActor.run {
                self.applyPathUpdate(normalizedURL, isDir: isDir, for: panel)
            }
        }
    }

    /// fileExists + isDirectory check off MainActor — never blocks UI on slow volumes.
    /// Remote URLs skip filesystem check entirely — always treated as directories.
    nonisolated private static func resolveURLOffMainActor(_ url: URL) async -> (URL, Bool) {
        // Remote URLs: skip FileManager (it can't resolve them), treat as dir
        if isRemotePath(url) { return (url, true) }
        return
            await Task.detached(priority: .userInitiated) {
                var isDirCheck: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirCheck),
                    !isDirCheck.boolValue
                {
                    log.debug("resolveURLOffMainActor: file → parent dir: \(url.path)")
                    return (url.deletingLastPathComponent(), false)
                }
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                return (url, exists && isDir.boolValue)
            }
            .value
    }

    /// Apply resolved path — pure MainActor UI update, no IO
    private func applyPathUpdate(_ normalizedURL: URL, isDir: Bool, for panel: PanelSide) {
        log.debug("\(#function) \(panel) → \(normalizedURL.path) isDir=\(isDir)")
        focusedPanel = panel
        tabManager(for: panel).updateActiveTabPath(normalizedURL)
        if !isNavigatingFromHistory {
            // Remote paths are always directory-like — record regardless of isDir flag
            if isDir || Self.isRemotePath(normalizedURL) {
                navigationHistory(for: panel).navigateTo(normalizedURL)
            }
            selectionsHistory.setCurrent(to: normalizedURL)
        }
        let panelURL = url(for: panel)
        if Self.isRemotePath(normalizedURL) && !Self.isRemotePath(panelURL) {
            self[panel: panel].savedLocalURL = panelURL
        }
        if panel == .left { leftURL = normalizedURL } else { rightURL = normalizedURL }
        // NOTE: Do NOT set selectedFile here — displayedFiles still contains stale data
        // from the previous directory. Selection is handled by refreshFiles() after scan completes.
    }

    func restoreLocalPath(for panel: PanelSide) async {
        guard let localURL = self[panel: panel].savedLocalURL else {
            log.warning("[AppState] no saved local path for \(panel)")
            return
        }
        log.info("[AppState] restoring local path \(panel): \(localURL.path)")
        updatePath(localURL, for: panel)
        await setScannerDirectoryAndRefresh(localURL.path, for: panel)
    }
}
