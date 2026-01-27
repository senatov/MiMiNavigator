//
// DragDropManager.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// Manages drag-and-drop operations between panels
@MainActor
@Observable
final class DragDropManager {
    /// Currently pending transfer operation (shown in confirmation dialog)
    var pendingOperation: FileTransferOperation?

    /// Whether the confirmation dialog is visible
    var showConfirmationDialog: Bool = false

    /// Currently dragged files (for visual feedback)
    var draggedFiles: [CustomFile] = []

    /// Currently highlighted drop target (folder or panel)
    var dropTargetPath: URL?

    // MARK: - Start dragging files
    func startDrag(files: [CustomFile], from panelSide: PanelSide) {
        log.debug("DragDropManager: started dragging \(files.count) items from \(panelSide)")
        draggedFiles = files
    }

    // MARK: - End drag operation
    func endDrag() {
        log.debug("DragDropManager: drag ended")
        draggedFiles = []
        dropTargetPath = nil
    }

    // MARK: - Set drop target highlight
    func setDropTarget(_ url: URL?) {
        dropTargetPath = url
    }

    // MARK: - Prepare transfer operation and show confirmation
    func prepareTransfer(
        files: [CustomFile],
        to destination: URL,
        from sourcePanelSide: PanelSide?
    ) {
        log.debug("DragDropManager: preparing transfer of \(files.count) items to \(destination.path)")

        // Check if dropping on same location
        if let firstFile = files.first {
            let sourceDir = firstFile.urlValue.deletingLastPathComponent()
            if sourceDir.path == destination.path {
                log.debug("DragDropManager: dropping on same directory, ignoring")
                endDrag()
                return
            }
        }

        pendingOperation = FileTransferOperation(
            sourceFiles: files,
            destinationPath: destination,
            sourcePanelSide: sourcePanelSide
        )
        showConfirmationDialog = true
    }

    // MARK: - Execute the transfer with chosen action
    func executeTransfer(action: FileTransferAction, appState: AppState) async {
        guard let operation = pendingOperation else {
            log.error("DragDropManager: no pending operation to execute")
            return
        }

        defer {
            pendingOperation = nil
            showConfirmationDialog = false
            endDrag()
        }

        switch action {
            case .abort:
                log.debug("DragDropManager: transfer aborted by user")
                return

            case .move:
                await performMove(operation: operation, appState: appState)

            case .copy:
                await performCopy(operation: operation, appState: appState)
        }
    }

    // MARK: - Perform move operation
    private func performMove(operation: FileTransferOperation, appState: AppState) async {
        log.info("DragDropManager: moving \(operation.sourceFiles.count) items to \(operation.destinationPath.path)")

        let fm = FileManager.default
        var successCount = 0
        var failedItems: [String] = []

        for file in operation.sourceFiles {
            let sourceURL = file.urlValue
            let destURL = operation.destinationPath.appendingPathComponent(sourceURL.lastPathComponent)

            do {
                if fm.fileExists(atPath: destURL.path) {
                    log.warning("DragDropManager: destination exists, skipping: \(destURL.path)")
                    failedItems.append("\(file.nameStr) (already exists)")
                    continue
                }

                try fm.moveItem(at: sourceURL, to: destURL)
                successCount += 1
                log.debug("DragDropManager: moved \(file.nameStr) → \(destURL.path)")
            } catch {
                log.error("DragDropManager: failed to move \(file.nameStr): \(error.localizedDescription)")
                failedItems.append("\(file.nameStr) (\(error.localizedDescription))")
            }
        }

        log.info("DragDropManager: move completed. Success: \(successCount), Failed: \(failedItems.count)")
        await refreshPanels(appState: appState, operation: operation)
    }

    // MARK: - Perform copy operation
    private func performCopy(operation: FileTransferOperation, appState: AppState) async {
        log.info("DragDropManager: copying \(operation.sourceFiles.count) items to \(operation.destinationPath.path)")

        let fm = FileManager.default
        var successCount = 0
        var failedItems: [String] = []

        for file in operation.sourceFiles {
            let sourceURL = file.urlValue
            var destURL = operation.destinationPath.appendingPathComponent(sourceURL.lastPathComponent)

            do {
                destURL = generateUniqueDestination(for: destURL, fileManager: fm)
                try fm.copyItem(at: sourceURL, to: destURL)
                successCount += 1
                log.debug("DragDropManager: copied \(file.nameStr) → \(destURL.path)")
            } catch {
                log.error("DragDropManager: failed to copy \(file.nameStr): \(error.localizedDescription)")
                failedItems.append("\(file.nameStr) (\(error.localizedDescription))")
            }
        }

        log.info("DragDropManager: copy completed. Success: \(successCount), Failed: \(failedItems.count)")
        await refreshPanels(appState: appState, operation: operation)
    }

    // MARK: - Generate unique destination path (adds suffix like " 2", " 3", etc.)
    private func generateUniqueDestination(for url: URL, fileManager: FileManager) -> URL {
        guard fileManager.fileExists(atPath: url.path) else { return url }

        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var counter = 2
        var newURL: URL

        repeat {
            let newName = ext.isEmpty ? "\(filename) \(counter)" : "\(filename) \(counter).\(ext)"
            newURL = directory.appendingPathComponent(newName)
            counter += 1
        } while fileManager.fileExists(atPath: newURL.path) && counter < 1000

        return newURL
    }

    // MARK: - Refresh affected panels
    private func refreshPanels(appState: AppState, operation: FileTransferOperation) async {
        let leftPath = URL(fileURLWithPath: appState.leftPath).standardizedFileURL
        let rightPath = URL(fileURLWithPath: appState.rightPath).standardizedFileURL
        let destPath = operation.destinationPath.standardizedFileURL

        if destPath.path.hasPrefix(leftPath.path) || leftPath.path.hasPrefix(destPath.path) {
            await appState.refreshLeftFiles()
        }

        if destPath.path.hasPrefix(rightPath.path) || rightPath.path.hasPrefix(destPath.path) {
            await appState.refreshRightFiles()
        }

        if let sourceSide = operation.sourcePanelSide {
            switch sourceSide {
                case .left:
                    await appState.refreshLeftFiles()
                case .right:
                    await appState.refreshRightFiles()
            }
        }
    }
}
