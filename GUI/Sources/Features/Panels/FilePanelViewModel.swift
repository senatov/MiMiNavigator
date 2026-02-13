// FilePanelViewModel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class FilePanelViewModel {
    let panelSide: PanelSide
    private let appState: AppState
    private let fetchFiles: @Sendable @concurrent (PanelSide) async -> Void

    init(
        panelSide: PanelSide,
        appState: AppState,
        fetchFiles: @escaping @Sendable @concurrent (PanelSide) async -> Void
    ) {
        self.panelSide = panelSide
        self.appState = appState
        self.fetchFiles = fetchFiles
    }

    // MARK: - Get sorted files (uses AppState's unified sorting)
    var sortedFiles: [CustomFile] {
        // AppState.displayedFiles already returns sorted files
        appState.displayedFiles(for: panelSide)
    }

    // MARK: - Handle path change
    func handlePathChange(to url: URL?) {
        guard let url else {
            log.warning("Attempted to set nil path for <<\(panelSide)>>")
            return
        }
        Task { @MainActor in
            appState.updatePath(url.path, for: panelSide)
            await fetchFiles(panelSide)
        }
    }

    // MARK: - Select file
    func select(_ file: CustomFile) {
        appState.select(file, on: panelSide)
        appState.showFavTreePopup = false
    }

    // MARK: - Clear selection on both panels
    func unselectAll() {
        appState.clearSelection(on: .left)
        appState.clearSelection(on: .right)
        appState.selectedDir.selectedFSEntity = nil
        appState.showFavTreePopup = false
    }
}
