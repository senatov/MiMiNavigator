    //
    //  FilePanelViewModel.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 11.08.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import Foundation
import SwiftUI

@MainActor
final class FilePanelViewModel: ObservableObject {
    let panelSide: PanelSide
    private let appState: AppState
    private let fetchFiles: @Sendable @concurrent (PanelSide) async -> Void
    
        // MARK: -
    init(
        panelSide: PanelSide,
        appState: AppState,
        fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void
    ) {
        log.debug(#function)
        self.panelSide = panelSide
        self.appState = appState
        self.fetchFiles = fetchFiles
    }
    
        // MARK: -
    var sortedFiles: [CustomFile] {
        log.debug(#function + " for side <<\(panelSide)>>")
        let files = appState.displayedFiles(for: panelSide)
        let sorted = files.sorted { a, b in
            let aIsFolder = a.isDirectory || a.isSymbolicDirectory
            let bIsFolder = b.isDirectory || b.isSymbolicDirectory
            if aIsFolder != bIsFolder {
                return aIsFolder && !bIsFolder
            }
            return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
        }
        return sorted
    }
    
        // MARK: -
    func handlePathChange(to url: URL?) {
        log.debug(#function + " for side <<\(panelSide)>>")
        guard let url else {
            log.warning("Tried to set nil path for side <<\(panelSide)>>")
            return
        }
        Task { @MainActor in
            appState.updatePath(url.absoluteString, for: panelSide)
            await fetchFiles(panelSide)
        }
    }
    
        // MARK: - Select file on this panel and clear other panel's selection
    func select(_ file: CustomFile) {
            // Centralized selection: update AppState and clear the opposite side via AppState API.
        log.debug("VM.select() on <<\(panelSide)>>: \(file.nameStr) [\(file.id)]")
        appState.select(file, on: panelSide)
        self.appState.showFavTreePopup = false
    }
    
        // periphery:ignore
        // MARK: - Clears selection on both panels and resets related fields in AppState.
    func unselectAll() {
        log.debug(#function + " — clearing selection on both panels")
        appState.clearSelection(on: .left)
        appState.clearSelection(on: .right)
        appState.selectedDir.selectedFSEntity = nil
        appState.showFavTreePopup = false
    }
}
