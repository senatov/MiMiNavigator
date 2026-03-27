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

    static let shared = DragDropManager()

    /// Currently pending transfer (shown in confirmation dialog)
    var pendingOperation: FileTransferOperation?

    /// Whether the confirmation dialog is visible
    var showConfirmationDialog: Bool = false

    /// Files being dragged in the current session (set by both SwiftUI .onDrag and AppKit NSDraggingSession)
    var draggedFiles: [CustomFile] = []

    /// Currently highlighted drop target folder
    var dropTargetPath: URL?

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
        let headerHeight: CGFloat = 26
        let rowHeight = FilePanelStyle.rowHeight
        let yInPanel = panelFrame.maxY - windowPoint.y
        let rowY = yInPanel - headerHeight
        guard rowY >= 0 else { return nil }
        let rowIndex = Int(floor(rowY / rowHeight))
        let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        guard rowIndex >= 0, rowIndex < files.count else { return nil }
        let file = files[rowIndex]
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
        log.debug("[DnD] prepareTransfer: \(files.count) file(s) → \(destination.lastPathComponent)")
        pendingOperation = FileTransferOperation(
            sourceFiles: files,
            destinationPath: destination,
            sourcePanelSide: sourcePanelSide
        )
        showConfirmationDialog = true
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
    private func performFileOp(
        _ kind: FileTransferAction,
        operation: FileTransferOperation,
        appState: AppState
    ) async {
        let urls = operation.sourceFiles.map(\.urlValue)
        let dest = operation.destinationPath
        // Remote → local: download via RemoteConnectionManager
        let sourceIsRemote = operation.sourceFiles.contains { AppState.isRemotePath($0.urlValue) }
        let destIsRemote = AppState.isRemotePath(dest)
        if sourceIsRemote && !destIsRemote {
            await performRemoteDownload(operation: operation, appState: appState)
            return
        }
        if destIsRemote {
            log.warning("[DnD] upload to remote not yet implemented")
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
        let totalSize = files.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        panel.showFileOp(
            icon: "arrow.down.doc.fill",
            title: "⬇ Downloading \(files.count) item(s) — \(sizeStr)",
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
        let leftURL = appState.leftURL
        let rightURL = appState.rightURL
        let leftIsRemote = AppState.isRemotePath(leftURL)
        let rightIsRemote = AppState.isRemotePath(rightURL)
        if !leftIsRemote {
            let leftPath = leftURL.standardizedFileURL.path
            if destPath.hasPrefix(leftPath) || leftPath.hasPrefix(destPath) {
                refreshed.insert(.left)
            }
        }
        if !rightIsRemote {
            let rightPath = rightURL.standardizedFileURL.path
            if destPath.hasPrefix(rightPath) || rightPath.hasPrefix(destPath) {
                refreshed.insert(.right)
            }
        }
        if let sourceSide = operation.sourcePanelSide {
            refreshed.insert(sourceSide)
        }
        for side in refreshed {
            await appState.refreshFiles(for: side)
        }
        log.debug("[DnD] refreshed panels: \(refreshed)")
    }
}
