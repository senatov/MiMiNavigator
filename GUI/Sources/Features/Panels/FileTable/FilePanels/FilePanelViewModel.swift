// FilePanelViewModel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import FileModelKit
import SwiftUI

@MainActor
@Observable
final class FilePanelViewModel {
    let panelSide: FavPanelSide
    private let appState: AppState
    // TODO: Remove fetchFiles — navigation now goes through AppState.navigateToDirectory
    private let fetchFiles: @Sendable @concurrent (FavPanelSide) async -> Void

    init(
        panelSide: FavPanelSide,
        appState: AppState,
        fetchFiles: @escaping @Sendable @concurrent (FavPanelSide) async -> Void
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

    // MARK: - Handle path change (breadcrumb, path bar)
    func handlePathChange(to url: URL?) {
        guard let url else {
            log.warning("Attempted to set nil path for <<\(panelSide)>>")
            return
        }
        let path = AppState.pathString(for: url)
        Task { @MainActor in
            await appState.navigateToDirectory(path, on: panelSide)
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
