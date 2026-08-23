// DragDropManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.

import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DragDropManager
/// Central coordinator for drag-and-drop between panels and external apps.
/// Owns pending transfer state, confirmation dialog, and drag session tracking.
@MainActor
@Observable
final class DragDropManager {
    private static let shared = DragDropManager()

    /// Currently pending transfer (shown in confirmation dialog)
    var pendingOperation: FileTransferOperation?

    /// Whether the confirmation dialog is visible
    var showConfirmationDialog: Bool = false

    /// Files being dragged in the current session (set by both SwiftUI .onDrag and AppKit NSDraggingSession)
    var draggedFiles: [CustomFile] = []

    /// Panel where the current internal drag started.
    var dragSourcePanelSide: FavPanelSide?

    private var dragCleanupTask: Task<Void, Never>?
    private var internalReleaseWatchTask: Task<Void, Never>?
    private weak var dragAppState: AppState?
    private var leftPanelWidth: CGFloat = 0
    private var panelsContainerWidth: CGFloat = 0

    /// Currently highlighted drop target folder
    var dropTargetPath: URL?

    /// Explicit destination supplied by a SwiftUI drop zone outside the file table.
    var dropDestinationOverride: URL?

    private func transferURLs(from files: [CustomFile]) -> [URL] {
        files.map(\.urlValue)
    }

    private func destinationIsRemote(_ destination: URL) -> Bool {
        AppState.isRemotePath(destination)
    }

    // MARK: - Start Drag
    /// Register files being dragged. Called from SwiftUI .onDrag (grid mode) and DragNSView (list mode).
    func startDrag(files: [CustomFile], from panelSide: FavPanelSide, appState: AppState? = nil) {
        log.debug("[DnD] drag started: \(files.count) item(s) from \(panelSide)")
        if let appState, appState.focusedPanel != panelSide {
            appState.focusedPanel = panelSide
            log.debug("[DnD] focus → \(panelSide) at drag start")
        }
        draggedFiles = files
        dragSourcePanelSide = panelSide
        dragAppState = appState
        scheduleStaleDragCleanup()
        startInternalReleaseWatchIfNeeded()
    }

    // MARK: - End Drag
    func endDrag() {
        dragCleanupTask?.cancel()
        dragCleanupTask = nil
        internalReleaseWatchTask?.cancel()
        internalReleaseWatchTask = nil
        draggedFiles = []
        dragSourcePanelSide = nil
        dragAppState = nil
        dropTargetPath = nil
        dropDestinationOverride = nil
    }

    private func scheduleStaleDragCleanup() {
        dragCleanupTask?.cancel()
        dragCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            guard !showConfirmationDialog, !draggedFiles.isEmpty else { return }
            log.debug("[DnD] stale drag cleanup: \(draggedFiles.count) item(s)")
            endDrag()
        }
    }

    // MARK: - Internal SwiftUI Drag Release Watch
    private func startInternalReleaseWatchIfNeeded() {
        guard dragAppState != nil else { return }
        internalReleaseWatchTask?.cancel()
        internalReleaseWatchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !draggedFiles.isEmpty else { return }
                if NSEvent.pressedMouseButtons == 0 {
                    completeInternalSwiftUIDragIfNeeded()
                    return
                }
            }
        }
    }

    private func completeInternalSwiftUIDragIfNeeded() {
        guard !draggedFiles.isEmpty else { return }
        guard pendingOperation == nil, !showConfirmationDialog else {
            endDrag()
            return
        }
        guard let appState = dragAppState,
              let sourceSide = dragSourcePanelSide,
              let dropContext = internalDropContext()
        else {
            log.debug("[DnD] SwiftUI drag release ignored: no window context")
            endDrag()
            return
        }
        guard dropContext.side != sourceSide else {
            log.debug("[DnD] SwiftUI drag release ignored: same panel")
            endDrag()
            return
        }
        let files = draggedFiles
        let destination = appState.url(for: dropContext.side)
        log.info("[DnD] SwiftUI internal drop: \(files.count) file(s) → \(dropContext.side) (\(destination.lastPathComponent))")
        prepareTransfer(files: files, to: destination, from: sourceSide)
        endDrag()
    }

    private func internalDropContext() -> (side: FavPanelSide, windowPoint: NSPoint)? {
        let mouseScreenPoint = NSEvent.mouseLocation
        guard let window = NSApp.windows.first(where: { window in
            !(window is NSPanel) && window.isVisible && window.frame.contains(mouseScreenPoint)
        }) else { return nil }
        guard DragDestinationWindowResolver.isWindowTopmost(window, at: mouseScreenPoint) else {
            return nil
        }
        let windowPoint = window.convertPoint(fromScreen: mouseScreenPoint)
        return (panelSide(atWindowX: windowPoint.x), windowPoint)
    }

    // MARK: - Panel Geometry
    func updatePanelGeometry(leftPanelWidth: CGFloat, containerWidth: CGFloat) {
        guard leftPanelWidth > 0, containerWidth > 0 else { return }
        self.leftPanelWidth = leftPanelWidth
        panelsContainerWidth = containerWidth
    }

    func panelSide(atWindowX x: CGFloat) -> FavPanelSide {
        let fallbackDivider = panelsContainerWidth > 0 ? panelsContainerWidth / 2 : x
        let dividerX = leftPanelWidth > 0 ? min(leftPanelWidth, panelsContainerWidth) : fallbackDivider
        return x < dividerX ? .left : .right
    }

    // MARK: - Set Drop Target
    func setDropTarget(_ url: URL?) {
        dropTargetPath = url
    }

    func setDropDestinationOverride(_ url: URL?) {
        dropDestinationOverride = url
    }

    // MARK: - Resolve Row Under Cursor
    /// Given a window Y coordinate and panel side, find the directory row under the cursor.
    /// Returns the directory URL if cursor is over a directory row, otherwise nil.
    func resolveDirectoryUnderCursor(
        windowPoint: NSPoint,
        panelSide: FavPanelSide,
        appState: AppState,
        panelFrame: NSRect
    ) -> URL? {
        let rowHeight = FilePanelStyle.rowHeight
        let yInPanel = panelFrame.maxY - windowPoint.y
        let rowY = yInPanel - TableHeaderStyle.height
        guard rowY >= 0 else { return nil }
        let rowIndex = Int(floor(rowY / rowHeight))
        let files = appState.displayedRows(for: panelSide)
        guard rowIndex >= 0, rowIndex < files.count else { return nil }
        let file = files[rowIndex]
        guard !ParentDirectoryEntry.isParentEntry(file) else { return nil }
        guard file.isDirectory || file.isSymbolicDirectory else { return nil }
        return file.urlValue
    }

    // MARK: - Prepare Transfer
    /// Stage a transfer operation and show confirmation dialog.
    func prepareTransfer(
        files: [CustomFile],
        to destination: URL,
        from sourcePanelSide: FavPanelSide?
    ) {
        log.debug("[DnD] prepareTransfer: \(files.count) file(s) → \(destinationDisplayName(destination))")
        InfoPopupController.hideAll(reason: "drag-drop-prepare", immediate: true)
        ProgressPanel.shared.hide()
        pendingOperation = makePendingOperation(
            files: files,
            destination: destination,
            sourcePanelSide: sourcePanelSide
        )
        showConfirmationDialog = true
    }

    private func makePendingOperation(
        files: [CustomFile],
        destination: URL,
        sourcePanelSide: FavPanelSide?
    ) -> FileTransferOperation {
        FileTransferOperation(
            sourceFiles: files,
            destinationPath: destination,
            sourcePanelSide: sourcePanelSide
        )
    }

    // MARK: - Execute Transfer
    func executeTransfer(action: FileTransferAction, appState: AppState) async {
        guard let operation = pendingOperation else {
            log.error("[DnD] executeTransfer called with no pending op")
            return
        }
        pendingOperation = nil
        showConfirmationDialog = false
        endDrag()
        await Task.yield()
        switch action {
            case .abort:
                log.debug("[DnD] transfer aborted")
            case .move:
                await performFileOp(.move, operation: operation, appState: appState)
            case .copy:
                await performFileOp(.copy, operation: operation, appState: appState)
        }
    }

    // MARK: - Perform File Operation
    private func sourceFilesAreRemote(_ files: [CustomFile]) -> Bool {
        !files.isEmpty && files.allSatisfy { AppState.isRemotePath($0.urlValue) }
    }

    private func sourceFilesAreLocal(_ files: [CustomFile]) -> Bool {
        !files.isEmpty && files.allSatisfy { !AppState.isRemotePath($0.urlValue) }
    }

    private func hasMixedSourceLocality(_ files: [CustomFile]) -> Bool {
        !files.isEmpty && !sourceFilesAreRemote(files) && !sourceFilesAreLocal(files)
    }

    private func performFileOp(
        _ kind: FileTransferAction,
        operation: FileTransferOperation,
        appState: AppState
    ) async {
        let files = operation.sourceFiles
        let urls = transferURLs(from: files)
        let dest = operation.destinationPath
        let sourceIsRemote = sourceFilesAreRemote(files)
        let sourceIsLocal = sourceFilesAreLocal(files)
        let destIsRemote = destinationIsRemote(dest)

        if hasMixedSourceLocality(files) {
            log.error("[DnD] mixed local/remote drag set is not supported")
            return
        }

        if sourceIsRemote && !destIsRemote {
            await performRemoteDownload(operation: operation, appState: appState)
            return
        }

        if sourceIsLocal && destIsRemote {
            await performRemoteUpload(kind, operation: operation, appState: appState)
            return
        }

        if sourceIsRemote && destIsRemote {
            log.warning("[DnD] remote to remote transfer not yet implemented")
            return
        }

        guard sourceIsLocal && !destIsRemote else {
            log.error("[DnD] invalid transfer routing state")
            return
        }

        log.info("[DnD] \(kind) \(urls.count) item(s) → \(dest.lastPathComponent)")
        do {
            let progress: FileOpProgress
            switch kind {
                case .move: progress = try await FileOpsEngine.shared.move(items: urls, to: dest)
                case .copy: progress = try await FileOpsEngine.shared.copy(items: urls, to: dest)
                case .abort: return
            }
            if kind == .move && progress.errors.isEmpty && !progress.isCancelled {
                if let sourceSide = operation.sourcePanelSide,
                   let archiveURL = appState.archiveState(for: sourceSide).archiveURL {
                    let marked = await ArchiveManager.shared.markDirty(archivePath: archiveURL.path)
                    log.info("[DnD] archive dirty after move=\(marked): \(archiveURL.lastPathComponent)")
                } else {
                    var markedCount = 0
                    for url in urls {
                        if await ArchiveManager.shared.markDirtyByTempPath(url.path) {
                            markedCount += 1
                        }
                    }
                    log.info("[DnD] archive dirty by source URL: \(markedCount)/\(urls.count)")
                }
            }
            let outcome: FileOperationOutcomePresenter.Operation = kind == .move ? .move : .copy
            if progress.isCancelled {
                FileOperationOutcomePresenter.cancelled(outcome)
            } else if progress.errors.isEmpty {
                FileOperationOutcomePresenter.success(outcome, itemCount: urls.count, resultURL: dest)
            } else {
                FileOperationOutcomePresenter.failure(outcome, message: progress.completionSummary)
            }
        } catch {
            log.error("[DnD] \(kind) failed: \(error.localizedDescription)")
            let outcome: FileOperationOutcomePresenter.Operation = kind == .move ? .move : .copy
            FileOperationOutcomePresenter.failure(outcome, error: error)
        }
        await refreshAffectedPanels(appState: appState, operation: operation)
    }

    private func panelPath(_ side: FavPanelSide, in appState: AppState) -> URL {
        switch side {
            case .left:
                return appState.leftURL
            case .right:
                return appState.rightURL
        }
    }

    // MARK: - Refresh Affected Panels
    /// Refresh only the panels whose directories overlap with source or destination.
    /// Uses Set to avoid double-refreshing the same panel.
    /// Remote panels are refreshed via refreshRemoteFiles, not local scanner.
    func refreshAffectedPanels(appState: AppState, operation: FileTransferOperation) async {
        if let sourceSide = operation.sourcePanelSide {
            appState.unmarkAll(on: sourceSide)
        }
        var refreshed = Set<FavPanelSide>()
        let destPath = operation.destinationPath.standardizedFileURL.path
        for side in [FavPanelSide.left, .right] {
            let panelURL = panelPath(side, in: appState)
            if AppState.isRemotePath(panelURL) {
                if panelURL.path == operation.destinationPath.path {
                    refreshed.insert(side)
                }
                continue
            }

            let panelPath = panelURL.standardizedFileURL.path
            if pathsOverlap(panelPath, destPath) {
                refreshed.insert(side)
            }
        }
        if let sourceSide = operation.sourcePanelSide {
            refreshed.insert(sourceSide)
        }
        for side in refreshed {
            let panelURL = panelPath(side, in: appState)
            if AppState.isRemotePath(panelURL) {
                await appState.refreshRemoteFiles(for: side)
            } else {
                await appState.refreshFiles(for: side)
            }
        }
        log.debug("[DnD] refreshed panels: \(refreshed)")
    }

    private func pathsOverlap(_ firstPath: String, _ secondPath: String) -> Bool {
        isAncestorOrSame(firstPath, of: secondPath)
            || isAncestorOrSame(secondPath, of: firstPath)
    }

    private func isAncestorOrSame(_ ancestorPath: String, of descendantPath: String) -> Bool {
        if ancestorPath == descendantPath { return true }
        if ancestorPath == "/" { return descendantPath.hasPrefix("/") }
        return descendantPath.hasPrefix(ancestorPath + "/")
    }
}
