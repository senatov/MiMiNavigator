// AppState+Navigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Directory navigation with retry + spinner for slow volumes, parent nav.
//              Uses setScannerDirectoryAndRefresh to avoid left/right branching.

import AppKit
import FileModelKit
import Foundation

// MARK: - Directory Navigation
extension AppState {

    /// Navigate into a directory with retry logic and spinner for slow volumes (USB, NAS).
    /// Shows cached content instantly if available, then refreshes in background.
    func navigateToDirectory(_ newPath: String, on panel: FavPanelSide) async {
        let previousPath = path(for: panel)
        log.info("[Navigate] \(panel): '\(previousPath)' → '\(newPath)'")

        // --- Remote navigation handling ---
        if let remoteURL = URL(string: newPath), Self.isRemotePath(remoteURL) {
            await navigateToRemoteDirectory(remoteURL, on: panel, previousPath: previousPath)
            return
        }
        // --- End remote navigation handling ---

        updatePath(newPath, for: panel)
        setSelectedFile(nil, for: panel)
        multiSelectionManager?.resetAnchor(for: panel)

        // --- Instant cache hit: show stale listing immediately, refresh in bg ---
        if let cached = await DirectoryContentCache.shared.lookup(newPath) {
            log.info("[Navigate] \(panel): cache HIT (\(cached.files.count) items, stale=\(cached.isStale))")
            if panel == .left { displayedLeftFiles = cached.files } else { displayedRightFiles = cached.files }
            if let f = firstRealFile(in: cached.files) { setSelectedFile(f, for: panel) }
            // background refresh — no spinner, no blocking
            Task { [weak self] in
                guard let self else { return }
                await self.scanner.clearCooldown(for: panel)
                await self.setScannerDirectoryAndRefresh(newPath, for: panel)
                // store fresh data in cache
                let fresh = self.displayedFiles(for: panel)
                if !fresh.isEmpty {
                    await DirectoryContentCache.shared.store(path: newPath, files: fresh)
                }
            }
            return
        }

        // --- Cache miss: scan with spinner + retry ---
        let spinnerTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            if !Task.isCancelled { navigatingPanel = panel }
        }
        defer {
            spinnerTask.cancel()
            navigatingPanel = nil
        }
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            await scanner.clearCooldown(for: panel)
            await setScannerDirectoryAndRefresh(newPath, for: panel)
            await MainActor.run {}
            let files = displayedFiles(for: panel)
            if !files.isEmpty && PathUtils.areEqual(path(for: panel), newPath) {
                log.info("[Navigate] \(panel): SUCCESS on attempt \(attempt), \(files.count) files")
                await DirectoryContentCache.shared.store(path: newPath, files: files)
                return
            }
            if PathUtils.areEqual(path(for: panel), newPath),
               Self.isReadableDirectory(newPath)
            {
                log.info("[Navigate] \(panel): empty but readable dir accepted (attempt \(attempt))")
                await DirectoryContentCache.shared.store(path: newPath, files: files)
                return
            }
            if attempt < maxAttempts {
                log.warning("[Navigate] \(panel): attempt \(attempt) got 0 files, retrying in 1s...")
                try? await Task.sleep(for: .seconds(1))
                if !PathUtils.areEqual(path(for: panel), newPath) {
                    log.info("[Navigate] \(panel): path changed externally, aborting retry")
                    return
                }
            }
        }
        if displayedFiles(for: panel).isEmpty || !PathUtils.areEqual(path(for: panel), newPath) {
            log.error("\(#function) \(panel): nav failed after \(maxAttempts) attempts → back to '\(previousPath)'")
            updatePath(previousPath, for: panel)
            await setScannerDirectoryAndRefresh(previousPath, for: panel)
            if Self.isUserNavigablePath(newPath) {
                Self.showNavFailAlert(path: newPath, panel: panel)
            }
        }
    }

    // MARK: - Remote directory navigation (extracted for clean code)
    private func navigateToRemoteDirectory(_ remoteURL: URL, on panel: FavPanelSide, previousPath: String) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else {
            log.error("[Navigate] \(panel): remote nav requested but no active connection")
            return
        }
        let remotePath = remoteURL.path.isEmpty ? "/" : remoteURL.path
        log.info("[Navigate] \(panel): remote enter '\(remotePath)'")
        do {
            let items = try await manager.listDirectory(remotePath)
            let files = items.map { CustomFile(remoteItem: $0) }
            let sorted = applySorting(files)
            let displayBase = Self.remoteOrigin(from: conn.provider.mountPath)
            let cleanURL = remotePath == "/" ? displayBase : displayBase + remotePath
            updatePath(cleanURL, for: panel)
            if panel == .left { displayedLeftFiles = sorted } else { displayedRightFiles = sorted }
            setSelectedFile(firstRealFile(in: sorted), for: panel)
            log.info("[Navigate] \(panel): remote SUCCESS, \(sorted.count) files")
        } catch {
            log.error("[Navigate] \(panel): remote FAILED '\(remotePath)' error=\(error.localizedDescription)")
        }
    }

    /// Handle ".." (parent directory) navigation — archive-aware
    func navigateToParent(on panel: FavPanelSide) async {
        let state = archiveState(for: panel)
        let currentURL = url(for: panel)
        let currentPath = currentURL.path
        if Self.isRemotePath(currentURL) {
            await navigateToParentRemote(on: panel)
            return
        }
        if state.isInsideArchive && state.isAtArchiveRoot(currentPath: currentPath) {
            await exitArchive(on: panel)
            return
        }
        let parentURL = currentURL.deletingLastPathComponent()
        guard parentURL.path != currentPath else {
            log.debug("[Navigate] \(panel): already at filesystem root")
            return
        }
        await navigateToDirectory(parentURL.path, on: panel)
    }

    /// Remote parent navigation — uses panel URL (not conn.currentPath which can lag)
    private func navigateToParentRemote(on panel: FavPanelSide) async {
        let manager = RemoteConnectionManager.shared
        guard manager.activeConnection != nil else { return }
        // Use the panel's actual URL — always current, never stale
        let currentRemotePath = url(for: panel).path
        let parentRemote = (currentRemotePath as NSString).deletingLastPathComponent
        let normalizedParent = parentRemote.isEmpty ? "/" : parentRemote
        log.info("[AppState] navigateToParent remote: \(currentRemotePath) → \(normalizedParent)")
        // Build full remote URL and navigate
        let origin = Self.remoteOrigin(from: manager.activeConnection?.provider.mountPath ?? "")
        let targetURL = normalizedParent == "/" ? origin : origin + normalizedParent
        await navigateToDirectory(targetURL, on: panel)
    }

    // MARK: - Navigation History
    func navigationHistory(for panel: FavPanelSide) -> PanelNavigationHistory {
        panel == .left ? leftNavigationHistory : rightNavigationHistory
    }

    func recordNavigation(to path: String, panel: FavPanelSide) {
        guard !isNavigatingFromHistory else { return }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            navigationHistory(for: panel).navigateTo(url)
        }
    }

    // MARK: - Nav fail helpers

    /// paths worth alerting on — real user dirs, not numeric/tmp/system junk
    nonisolated static func isUserNavigablePath(_ path: String) -> Bool {
        guard path.hasPrefix("/") else { return false }
        // skip pure-numeric last component (stale index saved as path)
        let last = (path as NSString).lastPathComponent
        if last.allSatisfy({ $0.isNumber }) { return false }
        // skip known system noise dirs
        let systemPrefixes = ["/tmp", "/var/folders", "/private/var", "/dev", "/proc"]
        if systemPrefixes.contains(where: { path.hasPrefix($0) }) { return false }
        return true
    }

    @MainActor
    private static func showNavFailAlert(path: String, panel: FavPanelSide) {
        log.warning("\(#function) panel=\(panel) path='\(path)'")
        ErrorAlertService.show(
            title: "Can't Open Folder",
            message: "Couldn't read contents of:\n\(path)\n\nPossible causes: no access permission, drive disconnected, or path no longer exists.",
            style: .warning
        )
    }

    /// Extracts "scheme://user@host[:port]" from a full mountPath URL string.
    /// e.g. "sftp://demo@test.rebex.net/pub/docs" → "sftp://demo@test.rebex.net"
    nonisolated static func remoteOrigin(from mountPath: String) -> String {
        guard let url = URL(string: mountPath),
              let scheme = url.scheme,
              let host   = url.host
        else { return mountPath }
        let userPart = url.user.map { "\($0)@" } ?? ""
        let portPart: String
        if let port = url.port,
           !((scheme == "sftp" && port == 22) || (scheme == "ftp" && port == 21)) {
            portPart = ":\(port)"
        } else {
            portPart = ""
        }
        return "\(scheme)://\(userPart)\(host)\(portPart)"
    }

    /// True when path exists as a directory AND FileManager can open it (even if empty).
    nonisolated static func isReadableDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
              isDir.boolValue
        else { return false }
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: path)
            return true
        } catch {
            return false
        }
    }
}
