//
// FilePanelViewModel.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class FilePanelViewModel {
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
            log.warning("tried to set nil path for <<\(panelSide)>>")
            return
        }
        Task { @MainActor in
            appState.updatePath(url.absoluteString, for: panelSide)
            await fetchFiles(panelSide)
        }
    }

    // MARK: -
    func select(_ file: CustomFile) {
        log.debug("[SELECT-FLOW] 2️⃣ FilePanelViewModel.select() on <<\(panelSide)>>: \(file.nameStr)")
        log.debug("[SELECT-FLOW] 2️⃣ Calling appState.select...")
        appState.select(file, on: panelSide)
        log.debug("[SELECT-FLOW] 2️⃣ Closing popups...")
        self.appState.showFavTreePopup = false
        log.debug("[SELECT-FLOW] 2️⃣ DONE")
    }

    // MARK: - periphery:ignore
    func unselectAll() {
        log.debug(#function + " — clearing sel on both panels")
        appState.clearSelection(on: .left)
        appState.clearSelection(on: .right)
        appState.selectedDir.selectedFSEntity = nil
        appState.showFavTreePopup = false
    }
}
