// DualDirectoryScanner+Publishing.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 30.03.2026.
// Description: MainActor publishing, cache sync, selection bootstrap and permission recovery.

import FileModelKit
import Foundation

extension DualDirectoryScanner {

    // MARK: - MainActor publish helpers

    @MainActor
    func applyPreviewFiles(_ files: [CustomFile], for side: FavPanelSide) {
        publishDisplayedFiles(files, for: side)
    }

    @MainActor
    func publishDisplayedFiles(_ files: [CustomFile], for side: FavPanelSide) {
        switch side {
            case .left:
                appState.displayedLeftFiles = files
            case .right:
                appState.displayedRightFiles = files
        }
    }

    // MARK: - Published files normalization

    @MainActor
    func currentDisplayedFiles(for side: FavPanelSide) -> [CustomFile] {
        switch side {
            case .left:
                return appState.displayedLeftFiles
            case .right:
                return appState.displayedRightFiles
        }
    }

    @MainActor
    func sanitizedPublishedFiles(from files: [CustomFile]) -> [CustomFile] {
        var sanitized = files
        var seenParent = false

        sanitized.removeAll { file in
            if file.isParentEntry {
                if seenParent { return true }
                seenParent = true
            }
            return false
        }

        if let parentIndex = sanitized.firstIndex(where: { $0.isParentEntry }), parentIndex != 0 {
            let parent = sanitized.remove(at: parentIndex)
            sanitized.insert(parent, at: 0)
        }

        return sanitized
    }

    // MARK: - Publish deduplication

    @MainActor
    func makeContentHash(for files: [CustomFile]) -> Int {
        var hasher = Hasher()
        hasher.combine(files.count)

        for file in files {
            hasher.combine(file.id)
        }

        return hasher.finalize()
    }

    @MainActor
    func shouldSkipIdenticalPublish(
        side: FavPanelSide,
        path: String,
        files: [CustomFile],
        contentHash: Int,
        isFirstUpdate: Bool
    ) -> Bool {
        guard !isFirstUpdate else { return false }

        let currentDisplayedCount = currentDisplayedFiles(for: side).count
        let samePathAsLastPublish = lastPublishedPathOnMain[side] == path
        let sameHashAsLastPublish = lastContentHashOnMain[side] == contentHash
        let sameVisibleCount = currentDisplayedCount == files.count

        guard samePathAsLastPublish,
              sameHashAsLastPublish,
              sameVisibleCount,
              currentDisplayedCount > 0
        else {
            return false
        }

        log.debug("[Scanner] Skip identical publish side=\(side) path='\(path)' count=\(currentDisplayedCount)")
        Task { await self.resetFSEventsDebounce(for: side) }
        return true
    }

    // MARK: - Selection bootstrap

    @MainActor
    func seedInitialSelectionIfNeeded(for side: FavPanelSide, files: [CustomFile]) {
        appState.ensureSelectionOnFocusedPanel()

        let firstFile = files.first
        let firstName = firstFile?.nameStr ?? "-"

        switch side {
            case .left where appState.selectedLeftFile == nil:
                appState.selectedLeftFile = firstFile
                log.debug("[Scanner] Auto-selected first left: \(firstName)")

            case .right where appState.selectedRightFile == nil:
                appState.selectedRightFile = firstFile
                log.debug("[Scanner] Auto-selected first right: \(firstName)")

            default:
                break
        }
    }

    // MARK: - MainActor scan publish

    @MainActor
    func updateScannedFiles(_ incomingFiles: [CustomFile], for side: FavPanelSide) {
        let publishedFiles = sanitizedPublishedFiles(from: incomingFiles)
        let now = Date()
        let isFirstUpdate = lastUpdateTime[side] == nil

        let sinceLastMs: String
        if let lastUpdate = lastUpdateTime[side] {
            sinceLastMs = "\(Int(now.timeIntervalSince(lastUpdate) * 1000))ms since last"
        } else {
            sinceLastMs = "first update"
        }

        let currentPath = currentPanelPathOnMain(for: side)
        let contentHash = makeContentHash(for: publishedFiles)

        if shouldSkipIdenticalPublish(
            side: side,
            path: currentPath,
            files: publishedFiles,
            contentHash: contentHash,
            isFirstUpdate: isFirstUpdate
        ) {
            return
        }

        lastContentHashOnMain[side] = contentHash
        lastPublishedPathOnMain[side] = currentPath
        lastUpdateTime[side] = now

        publishDisplayedFiles(publishedFiles, for: side)
        log.info("[Scanner] ✅ \(side) → \(publishedFiles.count) items (\(sinceLastMs))")

        if isFirstUpdate {
            seedInitialSelectionIfNeeded(for: side, files: publishedFiles)
        }
    }

    func publishSuccessfulScan(_ files: [CustomFile], scannedPath: String, for side: FavPanelSide) async {
        await updateScannedFiles(files, for: side)
        await updateFileList(panelSide: side, with: files)
        log.debug("[Scan] published successful scan side=\(side) path='\(scannedPath)' count=\(files.count)")
    }

    // MARK: - Permission helpers

    func isPermissionDeniedError(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain && error.code == 257 { return true }
        if error.domain == NSPOSIXErrorDomain && error.code == 13 { return true }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDeniedError(underlying)
        }

        return false
    }

    func rescanDirectoryAfterBookmarkRestore(_ url: URL, side: FavPanelSide) async -> Bool {
        do {
            let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
            let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
            log.info("[Permissions] Rescan succeeded: items=\(scanned.count) path='\(url.path)'")
            await updateScannedFiles(scanned, for: side)
            await updateFileList(panelSide: side, with: scanned)
            return true
        } catch {
            log.warning("[Permissions] Rescan after bookmark restore failed: \(error.localizedDescription)")
            return false
        }
    }

    func scanHomeDirectoryForFallback(_ homeURL: URL, side: FavPanelSide) async {
        do {
            let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
            let sortKey = await MainActor.run { appState.sortKey }
            let sortAsc = await MainActor.run { appState.bSortAscending }

            let scanned = try FileScanner.scan(url: homeURL, showHiddenFiles: showHidden)
            let sorted = FileSortingService.sort(scanned, by: sortKey, bDirection: sortAsc)

            await updateScannedFiles(sorted, for: side)
            await updateFileList(panelSide: side, with: sorted)

            log.info("[Permissions] Fallback to Home succeeded: items=\(sorted.count)")
        } catch {
            log.error("[Permissions] Home directory scan failed: \(error)")
        }
    }

    func requestAndRetryAccess(for url: URL, side: FavPanelSide) async -> Bool {
        log.info("[Permissions] Checking bookmarks for path='\(url.path)'")

        let restored = await BookmarkStore.shared.restoreAll()
        if !restored.isEmpty {
            log.info("[Permissions] Restored \(restored.count) bookmark(s), retrying scan")
            return await rescanDirectoryAfterBookmarkRestore(url, side: side)
        }

        log.warning("[Permissions] No bookmark for path='\(url.path)', falling back to Home directory")

        let homeURL = URL(fileURLWithPath: NSHomeDirectory())

        await MainActor.run {
            log.debug(#function + ": setting Home as the current directory")
            appState.setURL(homeURL, for: side)
        }

        await scanHomeDirectoryForFallback(homeURL, side: side)
        return false
    }

    // MARK: - Cache sync

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
