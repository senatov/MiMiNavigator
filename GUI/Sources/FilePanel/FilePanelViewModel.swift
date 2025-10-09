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
        log.info(#function)
        self.panelSide = panelSide
        self.appState = appState
        self.fetchFiles = fetchFiles
    }

    // MARK: -
    var sortedFiles: [CustomFile] {
        log.info(#function + " for side \(panelSide)")
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
        log.info(#function + " for side \(panelSide)")
        guard let url else {
            log.warning("Tried to set nil path for side \(panelSide)")
            return
        }
        Task { @MainActor in
            appState.updatePath(url.absoluteString, for: panelSide)
            await fetchFiles(panelSide)
        }
    }

    // MARK: - Select file on this panel and clear other panel's selection
    func select(_ file: CustomFile) {
        log.info(#function + " for file \(file.nameStr), side \(panelSide)")

        // Clear both to avoid double-selection and keep global invariants
        appState.selectedLeftFile = nil
        appState.selectedRightFile = nil

        switch panelSide {
            case .left:
                appState.selectedLeftFile = file
            case .right:
                appState.selectedRightFile = file
        }
        // Keep other global flags in sync
        appState.selectedDir.selectedFSEntity = file
        appState.showFavTreePopup = false
    }

    // periphery:ignore
    // MARK: - Clears selection on both panels and resets related fields in AppState.
    func unselectAll() {
        log.info(#function + " — clearing selection on both panels")
        appState.selectedLeftFile = nil
        appState.selectedRightFile = nil
        appState.selectedDir.selectedFSEntity = nil
        appState.showFavTreePopup = false
    }
}
