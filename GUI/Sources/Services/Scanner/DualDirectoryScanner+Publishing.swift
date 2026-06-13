// DualDirectoryScanner+Publishing.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 30.03.2026.
// Description: MainActor publishing, cache sync, selection bootstrap and permission recovery.

import FileModelKit
import Foundation

// MARK: - Scanner Publish State
struct ScannerPublishState {
    let samePath: Bool
    let sameHash: Bool
    let sameVisibleCount: Bool
    let currentDisplayedCount: Int
}

// MARK: - File Publish Fingerprint
private struct FilePublishFingerprint: Equatable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let isParentEntry: Bool
    let sizeVersion: Int
    let childCount: Int?
    let directorySize: Int64?
    let shallowSize: Int64?
    let sizeInBytes: Int64
    let sizeIsExact: Bool
    let modifiedTimestamp: TimeInterval?
    let securityState: String

    // MARK: - Init
    init(file: CustomFile) {
        id = file.id
        name = file.nameStr
        path = file.pathStr
        isDirectory = file.isDirectory
        isParentEntry = file.isParentEntry
        sizeVersion = file.sizeVersion
        childCount = file.cachedChildCount
        directorySize = file.cachedDirectorySize
        shallowSize = file.cachedShallowSize
        sizeInBytes = file.sizeInBytes
        sizeIsExact = file.sizeIsExact
        modifiedTimestamp = file.modifiedDate?.timeIntervalSince1970
        securityState = String(describing: file.securityState)
    }
}

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

    // MARK: - Publish entry points

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

    // MARK: - Cached metadata transfer

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
            transferred += transferDirectorySize(from: old, to: file)
            transferCachedMetadata(from: old, to: file)
        }
        if transferred > 0 {
            log.debug("[Scanner] transferred \(transferred) cached sizes to new file objects")
        }
    }

    // MARK: - Transfer Directory Size
    @MainActor
    private func transferDirectorySize(from old: CustomFile, to file: CustomFile) -> Int {
        guard file.cachedDirectorySize == nil,
              let oldSize = old.cachedDirectorySize,
              oldSize != DirectorySizeService.unavailableSize
        else {
            return 0
        }
        file.cachedDirectorySize = oldSize
        return 1
    }

    // MARK: - Transfer Cached Metadata
    @MainActor
    private func transferCachedMetadata(from old: CustomFile, to file: CustomFile) {
        if file.cachedShallowSize == nil { file.cachedShallowSize = old.cachedShallowSize }
        if old.sizeIsExact { file.sizeIsExact = true }
        if file.securityState == .normal { file.securityState = old.securityState }
        if old.sizeCalculationStarted { file.sizeCalculationStarted = true }
        if file.cachedAppSize == nil { file.cachedAppSize = old.cachedAppSize }
        if old.hasGeoTag { file.hasGeoTag = true }
        file.sizeVersion = old.sizeVersion
    }

    /// Cheap identity + metadata equality check to avoid triggering SwiftUI rebuilds on no-op publishes.
    /// Includes row fields that affect visible rendering for externally changed files.
    @MainActor
    private func filesAreIdentical(_ lhs: [CustomFile], _ rhs: [CustomFile]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices {
            let oldFingerprint = FilePublishFingerprint(file: lhs[index])
            let newFingerprint = FilePublishFingerprint(file: rhs[index])
            if oldFingerprint != newFingerprint { return false }
        }
        return true
    }

    // MARK: - Published files normalization
    // MARK: - Publish deduplication

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
            hasher.combine(file.cachedChildCount)
            hasher.combine(file.cachedDirectorySize)
            hasher.combine(file.cachedShallowSize)
            hasher.combine(file.sizeInBytes)
            hasher.combine(file.sizeIsExact)
            hasher.combine(file.modifiedDate?.timeIntervalSince1970 ?? 0)
            hasher.combine(String(describing: file.securityState))
        }
        return hasher.finalize()
    }

    @MainActor
    func shouldSkipIdenticalPublishState(
        side: FavPanelSide,
        path: String,
        files: [CustomFile],
        contentHash: Int
    ) -> ScannerPublishState {
        let currentDisplayedCount = currentDisplayedFiles(for: side).count
        let samePath = lastPublishedPathOnMain[side] == path
        let sameHash = lastContentHashOnMain[side] == contentHash
        let sameVisibleCount = currentDisplayedCount == files.count
        return ScannerPublishState(
            samePath: samePath,
            sameHash: sameHash,
            sameVisibleCount: sameVisibleCount,
            currentDisplayedCount: currentDisplayedCount
        )
    }

    // MARK: - Publish deduplication

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

        log.verbose("[Scanner] skip identical publish side=\(side) path='\(path)' count=\(state.currentDisplayedCount) hash=\(contentHash)")
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
            scheduleGeoTagScan(publishedFiles, for: side, path: currentPath)
            return
        }

        lastContentHashOnMain[side] = contentHash
        lastPublishedPathOnMain[side] = currentPath
        lastUpdateTime[side] = now

        publishDisplayedFiles(publishedFiles, for: side)
        scheduleGeoTagScan(publishedFiles, for: side, path: currentPath)
        log.info("[Scanner] published side=\(side) items=\(publishedFiles.count)")

        if isFirstUpdate {
            seedInitialSelectionIfNeeded(for: side, files: publishedFiles)
        }
    }

    func publishSuccessfulScan(_ files: [CustomFile], scannedPath: String, for side: FavPanelSide) async {
        log.debug("[Scan] publish side=\(side) path='\(scannedPath)' raw=\(files.count)")
        await MainActor.run {
            AutoFitScheduler.shared.runInitialPublishFit(panel: side, files: files)
        }
        await updateScannedFiles(files, for: side)
        await updateFileList(panelSide: side, with: files)
    }
}
