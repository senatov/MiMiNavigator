//
//  CntMenuCoord+CreationOps.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import Foundation

extension CntMenuCoord {

    // MARK: - Inline Rename
    /// Start TC-style inline rename for an item selected from the context menu.
    func beginInlineRename(file: CustomFile, panel: FavPanelSide, appState: AppState) {
        guard !file.isParentEntry, file.nameStr != ".." else { return }
        appState.setSelectedFile(file, for: panel)
        appState.focusedPanel = panel
        appState.inlineRename.begin(
            fileID: AnyHashable(file.id),
            fileName: file.nameStr,
            panelTag: panel == .left ? 0 : 1
        )
    }

    // MARK: - Create Folder
    /// Create new folder, then select it in the panel
    func performCreateFolder(name: String, at parentURL: URL, appState: AppState) async {
        log.debug("\(#function) name='\(name)' at='\(parentURL.path)'")
        isProcessing = true
        defer { isProcessing = false }
        let folderURL = childURL(name: name, parentURL: parentURL)
        do {
            if AppState.isRemotePath(parentURL) {
                let connection = try remoteConnection(for: parentURL)
                try await connection.provider.createDirectory(at: folderURL.path)
            } else {
                guard parentURL.isFileURL else { throw CocoaError(.fileNoSuchFile) }
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            }
            let panel = panelForURL(parentURL, appState: appState)
            await appState.refreshAndSelect(name: name, on: panel)
            let otherPanel: FavPanelSide = panel == .left ? .right : .left
            refreshPanel(otherPanel, appState: appState)
            activeDialog = nil
            log.info("\(#function) ok — '\(name)' created, selected on \(panel)")
        } catch {
            logCreationError(operation: "Create folder", targetURL: folderURL, error: error)
            activeDialog = nil
            showCreationError(title: L10n.Error.failedToCreateFolder, operation: "Create folder", targetURL: folderURL, error: error)
        }
    }

    // MARK: - Creation Helpers
    func childURL(name: String, parentURL: URL) -> URL {
        parentURL.appendingPathComponent(name)
    }

    func panelForURL(_ url: URL, appState: AppState) -> FavPanelSide {
        if PathUtils.areEqual(appState.url(for: .left), url) { return .left }
        if PathUtils.areEqual(appState.url(for: .right), url) { return .right }
        return appState.focusedPanel
    }

    func remoteConnection(for url: URL) throws -> RemoteConnection {
        let manager = RemoteConnectionManager.shared
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let user = url.user ?? ""
        let port = url.port
        if let connection = manager.connections.first(where: {
            $0.server.remoteProtocol.urlScheme == scheme
                && $0.server.host.lowercased() == host
                && ($0.server.user == user || user.isEmpty)
                && (port == nil || $0.server.port == port)
        }) {
            manager.setActive(id: connection.id, activatesPanel: false)
            return connection
        }
        throw RemoteProviderError.notConnected
    }

    func showCreationError(title: String, operation: String, targetURL: URL, error: Error) {
        let nsError = error as NSError
        let message = """
        Operation: \(operation)
        Path: \(targetURL.absoluteString)
        Reason: \(error.localizedDescription)
        OS error: \(nsError.domain) (\(nsError.code))
        """
        InAppNoticeCenter.shared.showError(title: title, message: message)
    }

    func logCreationError(operation: String, targetURL: URL, error: Error) {
        let nsError = error as NSError
        log.error("[Create] operation='\(operation)' path='\(targetURL.absoluteString)' error='\(error.localizedDescription)' domain='\(nsError.domain)' code=\(nsError.code)")
    }

    // MARK: - Paste
    /// Paste from clipboard
    func performPaste(to panel: FavPanelSide, appState: AppState) async {
        log.debug("\(#function) panel=\(panel) clipboardHasContent=\(clipboard.hasContent)")
        guard clipboard.hasContent else {
            log.warning("\(#function) clipboard is empty")
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        let destination = getDestinationPath(for: panel, appState: appState)
        let operation: FileOperationOutcomePresenter.Operation = clipboard.isCut ? .move : .copy
        let itemCount = max(clipboard.files.count, 1)
        let sourceURLs = clipboard.files
        log.debug("\(#function) destination='\(destination.path)'")
        let result = await clipboard.paste(to: destination)
        switch result {
            case .success(let urls):
                log.info("\(#function) SUCCESS pasted \(urls.count) item(s)")
                refreshPanels(appState: appState)
                let refresh = { @MainActor in self.refreshPanels(appState: appState) }
                let undo: FileOperationOutcomePresenter.UndoOperation?
                switch operation {
                    case .move:
                        undo = FileOperationOutcomePresenter.moveUndo(from: urls, to: sourceURLs, refresh: refresh)
                    case .copy:
                        undo = FileOperationOutcomePresenter.copyUndo(copiedURLs: urls, refresh: refresh)
                    default:
                        undo = nil
                }
                FileOperationOutcomePresenter.success(operation, itemCount: itemCount, resultURL: destination, sourceURLs: sourceURLs, undo: undo)
            case .failure(let error):
                if case FileOpsError.operationCancelled = error {
                    log.info("\(#function) cancelled by user")
                    FileOperationOutcomePresenter.cancelled(operation)
                } else {
                    log.error("\(#function) FAILED: \(error.localizedDescription)")
                    FileOperationOutcomePresenter.failure(operation, error: error)
                }
        }
    }

}
