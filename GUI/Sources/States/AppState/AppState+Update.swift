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

    private func fallbackLocalRestoreURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    private func resolvedRestoreLocalURL(for panel: FavPanelSide) -> URL {
        let fallbackURL = fallbackLocalRestoreURL()
        let savedURL = self[panel: panel].savedLocalURL

        guard let savedURL else {
            log.warning("[AppState] savedLocalURL missing for \(panel), restoring to home")
            return fallbackURL
        }

        let savedPath = savedURL.path
        guard !savedPath.isEmpty, savedPath != "/", savedPath != "/private" else {
            log.warning("[AppState] savedLocalURL invalid/root for \(panel), restoring to home")
            return fallbackURL
        }

        return savedURL
    }

    private func clearDisplayedFiles(for panel: FavPanelSide) {
        if panel == .left {
            displayedLeftFiles = []
        } else {
            displayedRightFiles = []
        }
    }

    private func setPanelURL(_ url: URL, for panel: FavPanelSide) {
        if panel == .left {
            leftURL = url
        } else {
            rightURL = url
        }
    }

    private func clearSavedLocalURL(for panel: FavPanelSide) {
        self[panel: panel].savedLocalURL = nil
    }

    private func updateTabPath(_ url: URL, for panel: FavPanelSide) {
        tabManager(for: panel).updateActiveTabPath(url)
    }

    private func displayedFileCount(for panel: FavPanelSide) -> Int {
        displayedFiles(for: panel).count
    }

    private func displayedFilesBecameVisible(for panel: FavPanelSide, attempts: Int = 8) async -> Bool {
        for _ in 0..<attempts {
            if displayedFileCount(for: panel) > 0 {
                return true
            }
            await Task.yield()
        }
        return displayedFileCount(for: panel) > 0
    }

    func updatePath(_ pathString: String, for panel: FavPanelSide) {
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

    func updateKnownDirectoryPath(_ url: URL, for panel: FavPanelSide) {
        applyPathUpdate(url.standardizedFileURL, isDir: true, for: panel)
    }

    func updatePath(_ newURL: URL, for panel: FavPanelSide) {
        // guard: mangled remote URL wrapped in fileURLWithPath — bail early
        if Self.isRemotePath(newURL) && newURL.scheme == "file" {
            log.warning("\(#function) mangled remote URL detected: \(newURL.absoluteString) — skipping local update")
            return
        }
        let currentURL = url(for: panel)
        guard !PathUtils.areEqual(currentURL, newURL) else { return }

        // Remote URLs: apply synchronously — no filesystem check needed,
        // ensures URL is set before refreshRemoteFiles() reads it
        if Self.isRemotePath(newURL) {
            applyPathUpdate(newURL, isDir: true, for: panel)
            return
        }

        // Local paths: fileExists/isDirectory can block on NAS/SMB — run off MainActor.
        // IMPORTANT: capture isNavigatingFromHistory NOW — the flag may be cleared
        // by the caller's defer before this fire-and-forget Task executes,
        // causing forward history to be truncated on Back/Forward nav.
        let historyNav = isNavigatingFromHistory
        Task {
            let (normalizedURL, isDir) = await Self.resolveURLOffMainActor(newURL)
            await MainActor.run {
                let saved = self.isNavigatingFromHistory
                self.isNavigatingFromHistory = historyNav
                self.applyPathUpdate(normalizedURL, isDir: isDir, for: panel)
                self.isNavigatingFromHistory = saved
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
    private func applyPathUpdate(_ normalizedURL: URL, isDir: Bool, for panel: FavPanelSide) {
        log.debug("\(#function) \(panel) → \(normalizedURL.path) isDir=\(isDir)")
        focusedPanel = panel
        updateTabPath(normalizedURL, for: panel)
        if !isNavigatingFromHistory {
            // Remote paths are always directory-like — record regardless of isDir flag
            if isDir || Self.isRemotePath(normalizedURL) {
                navigationHistory(for: panel).navigateTo(normalizedURL)
            }
            selectionsHistory.setCurrent(to: normalizedURL)
        }
        let panelURL = url(for: panel)
        // Save local path before switching to remote — but only if it's a real user directory
        // (not root "/", not empty, not already remote). This is the restore point on disconnect.
        if Self.isRemotePath(normalizedURL) && !Self.isRemotePath(panelURL) {
            let p = panelURL.path
            let isRealLocalDir = !p.isEmpty && p != "/" && p != "/private"
            if isRealLocalDir {
                self[panel: panel].savedLocalURL = panelURL
                log.debug("\(#function) saved local URL for \(panel): \(p)")
            } else {
                // Fall back to home directory if panel was at root
                let home = FileManager.default.homeDirectoryForCurrentUser
                self[panel: panel].savedLocalURL = home
                log.debug("\(#function) panel was at root, saved home instead: \(home.path)")
            }
        }
        if panel == .left { leftURL = normalizedURL } else { rightURL = normalizedURL }
        // NOTE: Do NOT set selectedFile here — displayedFiles still contains stale data
        // from the previous directory. Selection is handled by refreshFiles() after scan completes.
    }

    func restoreLocalPath(for panel: FavPanelSide) async {
        let localURL = resolvedRestoreLocalURL(for: panel)
        let localPath = localURL.path

        log.info("[AppState] restoring local path \(panel): \(localPath)")

        // 1. Clear stale remote rows first.
        clearDisplayedFiles(for: panel)

        // 2. Switch panel URL state back to local without re-entering remote-specific flow.
        setPanelURL(localURL, for: panel)
        updateTabPath(localURL, for: panel)
        clearSavedLocalURL(for: panel)

        // 3. Refresh scanner state for the restored local path.
        await scanner.clearCooldown(for: panel)
        await setScannerDirectoryAndRefresh(localPath, for: panel)

        var restoredFileCount = displayedFileCount(for: panel)
        if restoredFileCount == 0 {
            let becameVisible = await displayedFilesBecameVisible(for: panel)
            restoredFileCount = displayedFileCount(for: panel)

            if !becameVisible {
                log.warning("[AppState] restore produced 0 visible files for \(panel): \(localPath) — forcing local refresh")
                await refreshFiles(for: panel, force: true)
                _ = await displayedFilesBecameVisible(for: panel)
                restoredFileCount = displayedFileCount(for: panel)
            }
        }

        log.info("[AppState] restore done \(panel): \(localPath), files=\(restoredFileCount)")
    }
}
