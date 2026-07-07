// PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import FileModelKit
import SwiftUI

// MARK: - Panel file table section container

struct PanelFileTableSection: View {
    @Environment(AppState.self) var appState

    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: FavPanelSide
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void

    // Use singleton ColumnLayoutStore — avoids recreating ColumnLayoutModel on every SwiftUI rebuild
    private var columnLayout: ColumnLayoutModel {
        ColumnLayoutStore.shared.layout(for: panelSide)
    }

    private var filesViewIdentity: Int {
        var hasher = Hasher()
        hasher.combine(panelSide)
        hasher.combine(appState.path(for: panelSide))
        return hasher.finalize()
    }

    // MARK: - Body
    var body: some View {
        FileTableView(
            panelSide: panelSide,
            files: files,
            selectedID: $selectedID,
            layout: columnLayout,
            onSelect: handleSelection,
            onDoubleClick: onDoubleClick
        )
        .id(filesViewIdentity)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded {
                    activatePanel()
                }
        )
        .animation(nil, value: selectedID)
        .transaction { txn in
            txn.disablesAnimations = true
        }
    }

    // MARK: - Selection handler
    private func handleSelection(_ file: CustomFile) {
        activatePanel()
        log.debug("[PanelFileTableSection] handleSelection: \(file.nameStr)")
        selectedID = file.id
        onSelect(file)
    }

    private func activatePanel() {
        guard appState.focusedPanel != panelSide else { return }
        appState.focusedPanel = panelSide
        log.debug("[PanelFileTableSection] focus → \(panelSide)")
    }
}
