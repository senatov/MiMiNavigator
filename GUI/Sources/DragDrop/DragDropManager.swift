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
    private static let tableHeaderHeight: CGFloat = 24

    static let shared = DragDropManager()

    /// Currently pending transfer (shown in confirmation dialog)
    var pendingOperation: FileTransferOperation?

    /// Whether the confirmation dialog is visible
    var showConfirmationDialog: Bool = false

    /// Files being dragged in the current session (set by both SwiftUI .onDrag and AppKit NSDraggingSession)
    var draggedFiles: [CustomFile] = []

    /// Currently highlighted drop target folder
    var dropTargetPath: URL?

    private func transferURLs(from files: [CustomFile]) -> [URL] {
        files.map(\.urlValue)
    }

    private func destinationIsRemote(_ destination: URL) -> Bool {
        AppState.isRemotePath(destination)
    }

    private func normalizedRemoteDestinationPath(_ destination: URL) -> String {
        let path = destination.path
        return path.isEmpty ? "/" : path
    }

    private func destinationDisplayName(_ destination: URL) -> String {
        let normalizedPath = normalizedRemoteDestinationPath(destination)
        if normalizedPath == "/" {
            return "/"
        }

        return destination.lastPathComponent.isEmpty ? normalizedPath : destination.lastPathComponent
    }

    // MARK: - Start Drag
    /// Register files being dragged. Called from SwiftUI .onDrag (grid mode) and DragNSView (list mode).
    func startDrag(files: [CustomFile], from panelSide: FavPanelSide) {
        log.debug("[DnD] drag started: \(files.count) item(s) from \(panelSide)")
        draggedFiles = files
    }

    // MARK: - End Drag
    func endDrag() {
        draggedFiles = []
        dropTargetPath = nil
    }

    // MARK: - Set Drop Target
    func setDropTarget(_ url: URL?) {
        dropTargetPath = url
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
        let rowY = yInPanel - Self.tableHeaderHeight
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
    /// No validation here — let FileManager reject invalid ops at execution time.
    func prepareTransfer(
        files: [CustomFile],
        to destination: URL,
        from sourcePanelSide: FavPanelSide?
    ) {
        log.debug("[DnD] prepareTransfer: \(files.count) file(s) → \(destinationDisplayName(destination))")
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

        defer {
            pendingOperation = nil
            showConfirmationDialog = false
            endDrag()
        }

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
            switch kind {
                case .move: try await FileOpsEngine.shared.move(items: urls, to: dest)
                case .copy: try await FileOpsEngine.shared.copy(items: urls, to: dest)
                case .abort: return
            }
        } catch {
            log.error("[DnD] \(kind) failed: \(error.localizedDescription)")
        }
        await refreshAffectedPanels(appState: appState, operation: operation)
    }

    private func fileOperationTitle(for files: [CustomFile]) -> String {
        let totalSize = files.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        return "⬇ Downloading \(files.count) item(s) — \(sizeString)"
    }

    private func uploadOperationTitle(for files: [CustomFile]) -> String {
        let totalSize = files.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        let sizeString = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        return "⬆ Uploading \(files.count) item(s) — \(sizeString)"
    }

    private func remoteDestinationPath(for file: CustomFile, in destination: URL) -> String {
        let destinationPath = normalizedRemoteDestinationPath(destination)
        return destinationPath == "/"
            ? "/\(file.nameStr)"
            : destinationPath + "/\(file.nameStr)"
    }

    private func moveLocalItemToTrash(_ url: URL) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
    }

    // MARK: - Remote Upload (local → SFTP/FTP)
    private func performRemoteUpload(
        _ kind: FileTransferAction,
        operation: FileTransferOperation,
        appState: AppState
    ) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else {
            log.error("[DnD] remote upload — no active connection")
            return
        }

        let provider = conn.provider
        let destination = operation.destinationPath
        let files = operation.sourceFiles
        let panel = ProgressPanel.shared

        panel.showFileOp(
            icon: "arrow.up.doc.fill",
            title: uploadOperationTitle(for: files),
            itemCount: files.count,
            destination: normalizedRemoteDestinationPath(destination)
        )

        var ok = 0
        var fail = 0

        for (index, file) in files.enumerated() {
            guard !panel.isCancelled else {
                panel.appendLog("⛔ Cancelled")
                break
            }

            let localPath = file.urlValue.path
            let remotePath = remoteDestinationPath(for: file, in: destination)
            let isDirectory = file.isDirectory || file.isSymbolicDirectory

            panel.updateStatus("[\(index + 1)/\(files.count)] \(file.nameStr)")

            do {
                switch kind {
                    case .copy:
                        try await provider.uploadToRemote(
                            localPath: localPath,
                            remotePath: remotePath,
                            recursive: isDirectory
                        )
                    case .move:
                        try await provider.uploadToRemote(
                            localPath: localPath,
                            remotePath: remotePath,
                            recursive: isDirectory
                        )
                        try moveLocalItemToTrash(file.urlValue)
                    case .abort:
                        return
                }

                if isDirectory {
                    panel.appendLog("📁 \(file.nameStr)/")
                } else {
                    panel.appendLog("📄 \(file.nameStr)")
                }
                log.info("[DnD] uploaded '\(file.nameStr)' → '\(destinationDisplayName(destination))'")
                ok += 1
            } catch {
                log.error("[DnD] upload '\(file.nameStr)' failed: \(error.localizedDescription)")
                panel.appendLog("❌ \(file.nameStr): \(error.localizedDescription)")
                fail += 1
            }
        }

        log.info("[DnD] remote upload done: ok=\(ok) fail=\(fail)")
        if panel.isCancelled {
            panel.finish(success: false, message: "⏹ Cancelled — \(ok)/\(files.count)")
        } else if fail > 0 {
            panel.finish(success: false, message: "⚠️ \(ok) ok, \(fail) failed")
        } else {
            panel.finish(success: true, message: "✅ \(ok) item(s) uploaded")
        }

        await refreshAffectedPanels(appState: appState, operation: operation)
    }

    // MARK: - Remote Download (SFTP/FTP → local)
    private func performRemoteDownload(
        operation: FileTransferOperation,
        appState: AppState
    ) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else {
            log.error("[DnD] remote download — no active connection")
            return
        }
        let dest = operation.destinationPath
        let provider = conn.provider
        let panel = ProgressPanel.shared
        let files = operation.sourceFiles
        panel.showFileOp(
            icon: "arrow.down.doc.fill",
            title: fileOperationTitle(for: files),
            itemCount: files.count,
            destination: dest.path
        )
        var ok = 0
        var fail = 0
        for (idx, file) in files.enumerated() {
            guard !panel.isCancelled else {
                panel.appendLog("⛔ Cancelled")
                break
            }
            let remotePath = file.urlValue.path
            let finalURL = dest.appendingPathComponent(file.nameStr)
            let isDir = file.isDirectory
            panel.updateStatus("[\(idx + 1)/\(files.count)] \(file.nameStr)")
            do {
                if isDir {
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try FileManager.default.removeItem(at: finalURL)
                    }
                    try await provider.downloadToLocal(
                        remotePath: remotePath, localPath: finalURL.path, recursive: true
                    )
                    panel.appendLog("📁 \(file.nameStr)/")
                } else {
                    let tmpURL = try await provider.downloadFile(remotePath: remotePath)
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try FileManager.default.removeItem(at: finalURL)
                    }
                    try FileManager.default.moveItem(at: tmpURL, to: finalURL)
                    let sz = (try? FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as? Int64) ?? 0
                    panel.appendLog("📄 \(file.nameStr) (\(ByteCountFormatter.string(fromByteCount: sz, countStyle: .file)))")
                }
                log.info("[DnD] downloaded '\(file.nameStr)' → '\(dest.lastPathComponent)'")
                ok += 1
            } catch {
                log.error("[DnD] download '\(file.nameStr)' failed: \(error.localizedDescription)")
                panel.appendLog("❌ \(file.nameStr): \(error.localizedDescription)")
                fail += 1
            }
        }
        log.info("[DnD] remote download done: ok=\(ok) fail=\(fail)")
        if panel.isCancelled {
            panel.finish(success: false, message: "⏹ Cancelled — \(ok)/\(files.count)")
        } else if fail > 0 {
            panel.finish(success: false, message: "⚠️ \(ok) ok, \(fail) failed")
        } else {
            panel.finish(success: true, message: "✅ \(ok) item(s) downloaded")
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
    private func refreshAffectedPanels(appState: AppState, operation: FileTransferOperation) async {
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
            if destPath.hasPrefix(panelPath) || panelPath.hasPrefix(destPath) {
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
}
