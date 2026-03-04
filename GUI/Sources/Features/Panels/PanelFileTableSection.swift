// PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Panel file table section container
struct PanelFileTableSection: View {
    @Environment(AppState.self) var appState
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: PanelSide
    let onPanelTap: (PanelSide) -> Void
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void

    // Use singleton store — no more @State recreation on every render
    private var layout: ColumnLayoutModel {
        ColumnLayoutStore.shared.layout(for: panelSide)
    }

    var body: some View {
        FileTableView(
            panelSide: panelSide,
            files: files,
            selectedID: $selectedID,
            layout: layout,
            onSelect: handleSelection,
            onDoubleClick: onDoubleClick
        )
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded {
                    if appState.focusedPanel != panelSide {
                        appState.focusedPanel = panelSide
                    }
                }
        )
        .animation(nil, value: selectedID)
        .transaction { txn in
            txn.disablesAnimations = true
        }
    }

    // MARK: - Selection handler
    private func handleSelection(_ file: CustomFile) {
        if appState.focusedPanel != panelSide {
            appState.focusedPanel = panelSide
        }
        notifyWillSelect(file)
        onSelect(file)
    }

    private func notifyWillSelect(_ file: CustomFile) {
        NotificationCenter.default.post(
            name: .panelWillSelectFile,
            object: nil,
            userInfo: [
                "panelSide": panelSide,
                "fileID": file.id,
                "fileName": file.nameStr,
            ]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let panelWillSelectFile = Notification.Name("PanelWillSelectFile")
}
