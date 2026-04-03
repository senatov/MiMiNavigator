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
    func displayedFilesBinding(for side: FavPanelSide) -> [CustomFile] {
        switch side {
            case .left:
                return appState.displayedLeftFiles
            case .right:
                return appState.displayedRightFiles
        }
    }

    @MainActor
    func setDisplayedFiles(_ files: [CustomFile], for side: FavPanelSide) {
        switch side {
            case .left:
                appState.displayedLeftFiles = files
            case .right:
                appState.displayedRightFiles = files
        }
    }

    @MainActor
    func panelSelection(for side: FavPanelSide) -> CustomFile? {
        switch side {
            case .left:
                return appState.selectedLeftFile
            case .right:
                return appState.selectedRightFile
        }
    }

    @MainActor
    func setPanelSelection(_ file: CustomFile?, for side: FavPanelSide) {
        switch side {
            case .left:
                appState.selectedLeftFile = file
            case .right:
                appState.selectedRightFile = file
        }
    }

    // MARK: - MainActor publish helpers

    @MainActor
    func applyPreviewFiles(_ files: [CustomFile], for side: FavPanelSide) {
        // skip preview if full list is already displayed — avoids replacing
        // 185 items with 150-item preview, which causes SwiftUI view recreation
        // and scroll position reset
        let currentCount = displayedFilesBinding(for: side).count
        if currentCount >= files.count {
            log.debug("[Scanner] preview skip — already have \(currentCount) items (preview=\(files.count))")
            return
        }
        publishDisplayedFiles(files, for: side)
    }

    @MainActor
    func publishDisplayedFiles(_ files: [CustomFile], for side: FavPanelSide) {
        let current = displayedFilesBinding(for: side)
        if filesAreIdentical(current, files) {
            return
        }
        // carry over cached sizes from old objects — scanner creates fresh
        // CustomFile instances that don't have size data computed by FileRow
        transferCachedSizes(from: current, to: files)
        setDisplayedFiles(files, for: side)
    }


    /// Transfer cached directory/shallow sizes + security state from old CustomFile
    /// instances to new ones created by FileScanner. Keyed by pathStr (stable identity).
    /// Without this, every scanner republish wipes out sizes that FileRow already computed.
    @MainActor
    private func transferCachedSizes(from oldFiles: [CustomFile], to newFiles: [CustomFile]) {
        guard !oldFiles.isEmpty else { return }
        let lookup = Dictionary(oldFiles.map { ($0.pathStr, $0) }, uniquingKeysWith: { $1 })
        var transferred = 0
        for file in newFiles {
            guard file.isDirectory, let old = lookup[file.pathStr] else { continue }
            if file.cachedDirectorySize == nil, let oldSize = old.cachedDirectorySize {
                file.cachedDirectorySize = oldSize
                transferred += 1
            }
            if file.cachedShallowSize == nil, let oldShallow = old.cachedShallowSize {
                file.cachedShallowSize = oldShallow
            }
            if old.sizeIsExact && !file.sizeIsExact {
                file.sizeIsExact = old.sizeIsExact
            }
            if old.securityState != .normal && file.securityState == .normal {
                file.securityState = old.securityState
            }
            if old.sizeCalculationStarted {
                file.sizeCalculationStarted = old.sizeCalculationStarted
            }
            if let oldAppSize = old.cachedAppSize, file.cachedAppSize == nil {
                file.cachedAppSize = oldAppSize
            }
            // sync sizeVersion so filesAreIdentical doesn't see a diff
            // (setting cachedDirectorySize above bumps sizeVersion via didSet,
            // but the old object may have been bumped multiple times)
            if old.sizeVersion != file.sizeVersion {
                file.sizeVersion = old.sizeVersion
            }
        }
        if transferred > 0 {
            log.debug("[Scanner] transferred \(transferred) cached sizes to new file objects")
        }
    }



    /// Cheap identity+size check to avoid triggering SwiftUI rebuild on no-op publishes.
    /// Compares id, name, path, sizeVersion, cachedChildCount — the fields that affect row display.
    @MainActor
    private func filesAreIdentical(_ lhs: [CustomFile], _ rhs: [CustomFile]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in lhs.indices {
            let a = lhs[i]
            let b = rhs[i]
            if a.id != b.id { return false }
            if a.nameStr != b.nameStr { return false }
            if a.sizeVersion != b.sizeVersion { return false }
            if a.cachedChildCount != b.cachedChildCount { return false }
        }
        return true
    }

    // MARK: - Published files normalization

    @MainActor
    func currentDisplayedFiles(for side: FavPanelSide) -> [CustomFile] {
        return displayedFilesBinding(for: side)
    }

    @MainActor
    func sanitizedPublishedFiles(from files: [CustomFile]) -> [CustomFile] {
        var sanitized = files
        let originalCount = files.count
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
        log.verbose("[Scanner] sanitizedPublishedFiles original=\(originalCount) sanitized=\(sanitized.count)")
        return sanitized
    }

    // MARK: - Publish deduplication
    @MainActor
    func makeContentHash(for files: [CustomFile]) -> Int {
        var hasher = Hasher()
        hasher.combine(files.count)
        for file in files {
            hasher.combine(file.id)
            hasher.combine(file.nameStr)
            hasher.combine(file.pathStr)
            hasher.combine(file.isDirectory)
            hasher.combine(file.isParentEntry)
        }
        let hash = hasher.finalize()
        return hash
    }

    @MainActor
    func shouldSkipIdenticalPublishState(
        side: FavPanelSide,
        path: String,
        files: [CustomFile],
        contentHash: Int
    ) -> (samePath: Bool, sameHash: Bool, sameVisibleCount: Bool, currentDisplayedCount: Int) {
        let currentDisplayedCount = currentDisplayedFiles(for: side).count
        let samePath = lastPublishedPathOnMain[side] == path
        let sameHash = lastContentHashOnMain[side] == contentHash
        let sameVisibleCount = currentDisplayedCount == files.count
        return (samePath, sameHash, sameVisibleCount, currentDisplayedCount)
    }

    @MainActor
    func shouldSkipIdenticalPublish(
        side: FavPanelSide,
        path: String,
        files: [CustomFile],
        contentHash: Int,
        isFirstUpdate: Bool
    ) -> Bool {
        guard !isFirstUpdate else {
            return false
        }

        let state = shouldSkipIdenticalPublishState(
            side: side,
            path: path,
            files: files,
            contentHash: contentHash
        )

        guard state.samePath,
              state.sameHash,
              state.sameVisibleCount,
              state.currentDisplayedCount > 0
        else {
            return false
        }

        log.verbose("[Scanner] skip identical publish side=\(side) path='\(path)' count=\(state.currentDisplayedCount)")
        Task { await self.resetFSEventsDebounce(for: side) }
        return true
    }

    // MARK: - Selection bootstrap

    @MainActor
    func seedInitialSelectionIfNeeded(for side: FavPanelSide, files: [CustomFile]) {
        appState.ensureSelectionOnFocusedPanel()
        log.debug("[Scanner] seedInitialSelectionIfNeeded")
        log.debug("[Scanner] side=\(side) files=\(files.count)")

        guard panelSelection(for: side) == nil else {
            return
        }

        let firstFile = files.first
        let firstName = firstFile?.nameStr ?? "-"
        setPanelSelection(firstFile, for: side)

        log.debug("[Scanner] auto-selected first file")
        log.debug("[Scanner] side=\(side) name=\(firstName)")
    }

    // MARK: - MainActor scan publish

    @MainActor
    func updateScannedFiles(_ incomingFiles: [CustomFile], for side: FavPanelSide) {
        let publishedFiles = sanitizedPublishedFiles(from: incomingFiles)
        let now = Date()
        let isFirstUpdate = lastUpdateTime[side] == nil

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
        log.info("[Scanner] published side=\(side) items=\(publishedFiles.count)")

        if isFirstUpdate {
            seedInitialSelectionIfNeeded(for: side, files: publishedFiles)
        }
    }

    func publishSuccessfulScan(_ files: [CustomFile], scannedPath: String, for side: FavPanelSide) async {
        let publishedFiles = await MainActor.run {
            sanitizedPublishedFiles(from: files)
        }

        log.debug("[Scan] publish side=\(side) path='\(scannedPath)' raw=\(files.count) sanitized=\(publishedFiles.count)")

        await updateScannedFiles(publishedFiles, for: side)
        await updateFileList(panelSide: side, with: publishedFiles)
    }

    // MARK: - Permission helpers

    func isPermissionDeniedError(_ error: NSError) -> Bool {
        log.debug("[Permissions] isPermissionDeniedError")
        log.debug("[Permissions] domain=\(error.domain) code=\(error.code)")
        if error.domain == NSCocoaErrorDomain && error.code == 257 { return true }
        if error.domain == NSPOSIXErrorDomain && error.code == 13 { return true }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDeniedError(underlying)
        }

        log.debug("[Permissions] isPermissionDeniedError -> false")
        return false
    }

    func rescanDirectoryAfterBookmarkRestore(_ url: URL, side: FavPanelSide) async -> Bool {
        log.info("[Permissions] Rescan after bookmark restore start")
        log.info("[Permissions] side=\(side) path='\(url.path)'")
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
        log.info("[Permissions] scanHomeDirectoryForFallback start")
        log.info("[Permissions] side=\(side) path='\(homeURL.path)'")
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
        log.info("[Permissions] requestAndRetryAccess start")
        log.info("[Permissions] side=\(side) path='\(url.path)'")
        log.info("[Permissions] checking bookmarks")

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
