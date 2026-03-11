    //
    // DragDropManager.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 22.01.2026.
    //  Copyright © 2026 Senatov. All rights reserved.
    //

    import SwiftUI
    import FileModelKit
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

        /// NSPasteboard providers for current drag session
        var dragItemProviders: [NSItemProvider] = []

        /// Currently highlighted drop target (folder or panel)
        var dropTargetPath: URL?

        // MARK: - Start dragging files
        func startDrag(files: [CustomFile], from panelSide: PanelSide) {
            log.debug("DragDropManager: started dragging \(files.count) items from \(panelSide)")

            draggedFiles = files

            // Create one NSItemProvider per file (required for multi-file drag)
            dragItemProviders = files.map { file in
                let provider = NSItemProvider(object: file.urlValue as NSURL)
                provider.suggestedName = file.nameStr
                return provider
            }
        }

        // MARK: - End drag operation
        func endDrag() {
            log.debug("DragDropManager: drag ended")
            draggedFiles = []
            dragItemProviders = []
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

        // MARK: - Perform move via FileOpsEngine
        private func performMove(operation: FileTransferOperation, appState: AppState) async {
            log.info("DragDropManager: move \(operation.sourceFiles.count) items → \(operation.destinationPath.path)")
            let urls = operation.sourceFiles.map(\.urlValue)
            do {
                try await FileOpsEngine.shared.move(items: urls, to: operation.destinationPath)
            } catch {
                log.error("DragDropManager: move failed — \(error.localizedDescription)")
            }
            await refreshPanels(appState: appState, operation: operation)
        }

        // MARK: - Perform copy via FileOpsEngine
        private func performCopy(operation: FileTransferOperation, appState: AppState) async {
            log.info("DragDropManager: copy \(operation.sourceFiles.count) items → \(operation.destinationPath.path)")
            let urls = operation.sourceFiles.map(\.urlValue)
            do {
                try await FileOpsEngine.shared.copy(items: urls, to: operation.destinationPath)
            } catch {
                log.error("DragDropManager: copy failed — \(error.localizedDescription)")
            }
            await refreshPanels(appState: appState, operation: operation)
        }

        // MARK: - Refresh affected panels and clear marks
        private func refreshPanels(appState: AppState, operation: FileTransferOperation) async {
            // Clear marks after successful operation
            if let sourceSide = operation.sourcePanelSide {
                appState.unmarkAll(on: sourceSide)
                log.debug("DragDropManager: cleared marks on \(sourceSide) after operation")
            }

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
