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
    @Published var selectedFileID: CustomFile.ID?
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
        let directories = files
            .filter { $0.isDirectory || $0.isSymbolicDirectory }
            .sorted { $0.nameStr.localizedCompare($1.nameStr) == .orderedAscending }
        let others = files
            .filter { !($0.isDirectory || $0.isSymbolicDirectory) }
            .sorted { $0.nameStr.localizedCompare($1.nameStr) == .orderedAscending }
        return directories + others
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

    // MARK: -
    func select(_ file: CustomFile) {
        log.info(#function + " for file \(file.nameStr), side \(panelSide)")
        log.info("Selected file: '\(file.pathStr)' in panel \(panelSide)")
        selectedFileID = file.id
        appState.selectedDir.selectedFSEntity = file
        appState.showFavTreePopup = false
    }
}
