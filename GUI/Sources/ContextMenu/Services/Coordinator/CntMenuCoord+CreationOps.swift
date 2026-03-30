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

extension ContextMenuCoordinator {

    // MARK: - Create Folder
    /// Create new folder, then select it in the panel
    func performCreateFolder(name: String, at parentURL: URL, appState: AppState) async {
        log.debug("\(#function) name='\(name)' at='\(parentURL.path)'")
        // guard: reject remote / mangled URLs — can't create local folder there
        guard !AppState.isRemotePath(parentURL) && parentURL.isFileURL else {
            log.error("\(#function) aborted — parentURL is remote or non-local: \(parentURL.absoluteString)")
            activeDialog = .error(
                title: L10n.Error.failedToCreateFolder, message: "Can't create folder in remote path: \(parentURL.lastPathComponent)")
            return
        }
        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }
        let folderURL = parentURL.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            let panel = panelForPath(parentURL.path, appState: appState)
            await appState.refreshAndSelect(name: name, on: panel)
            let otherPanel: FavPanelSide = panel == .left ? .right : .left
            refreshPanel(otherPanel, appState: appState)
            log.info("\(#function) ok — '\(name)' created, selected on \(panel)")
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: L10n.Error.failedToCreateFolder, message: error.localizedDescription)
        }
    }

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
        log.debug("\(#function) destination='\(destination.path)'")

        let result = await clipboard.paste(to: destination, coordinator: self)

        switch result {
            case .success(let urls):
                log.info("\(#function) SUCCESS pasted \(urls.count) item(s)")
                refreshPanels(appState: appState)

            case .failure(let error):
                if case FileOpsError.operationCancelled = error {
                    log.info("\(#function) cancelled by user")
                } else {
                    log.error("\(#function) FAILED: \(error.localizedDescription)")
                    activeDialog = .error(title: "Paste Failed", message: error.localizedDescription)
                }
        }
    }

}
