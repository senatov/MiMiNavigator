// DualDirectoryScanner+Permissions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 13.06.2026.
// Description: Permission recovery, bookmark retry and scanner cache synchronization.

import FileModelKit
import Foundation

extension DualDirectoryScanner {
    // MARK: - Permission Error Detection
    func isPermissionDeniedError(_ error: NSError) -> Bool {
        log.debug("[Permissions] domain=\(error.domain) code=\(error.code)")
        if error.domain == NSCocoaErrorDomain && error.code == 257 { return true }
        if error.domain == NSPOSIXErrorDomain && error.code == 13 { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDeniedError(underlying)
        }
        return false
    }

    // MARK: - Bookmark Rescan
    func rescanDirectoryAfterBookmarkRestore(_ url: URL, side: FavPanelSide) async -> Bool {
        log.info("[Permissions] bookmark rescan side=\(side) path='\(url.path)'")
        do {
            let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
            let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
            await updateScannedFiles(scanned, for: side)
            await updateFileList(panelSide: side, with: scanned)
            log.info("[Permissions] bookmark rescan succeeded items=\(scanned.count)")
            return true
        } catch {
            log.warning("[Permissions] bookmark rescan failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Home Directory Fallback
    func scanHomeDirectoryForFallback(_ homeURL: URL, side: FavPanelSide) async {
        log.info("[Permissions] home fallback side=\(side) path='\(homeURL.path)'")
        do {
            let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
            let sortKey = await MainActor.run { appState.sortKey }
            let sortAsc = await MainActor.run { appState.bSortAscending }
            let scanned = try FileScanner.scan(url: homeURL, showHiddenFiles: showHidden)
            let sorted = FileSortingService.sort(scanned, by: sortKey, bDirection: sortAsc)
            await updateScannedFiles(sorted, for: side)
            await updateFileList(panelSide: side, with: sorted)
            log.info("[Permissions] home fallback succeeded items=\(sorted.count)")
        } catch {
            log.error("[Permissions] home fallback failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Request and Retry Access
    func requestAndRetryAccess(for url: URL, side: FavPanelSide) async -> Bool {
        log.info("[Permissions] checking bookmarks side=\(side) path='\(url.path)'")
        let restored = await BookmarkStore.shared.restoreAll()
        if !restored.isEmpty {
            log.info("[Permissions] restored \(restored.count) bookmark(s)")
            return await rescanDirectoryAfterBookmarkRestore(url, side: side)
        }
        log.warning("[Permissions] no bookmark; falling back to Home")
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        await MainActor.run {
            appState.setURL(homeURL, for: side)
        }
        await scanHomeDirectoryForFallback(homeURL, side: side)
        return false
    }

    // MARK: - Cache Synchronization
    @MainActor
    func updateFileList(panelSide: FavPanelSide, with files: [CustomFile]) async {
        switch panelSide {
        case .left:
            await fileCache.updateLeftFiles(files)
        case .right:
            await fileCache.updateRightFiles(files)
        }
    }
}
