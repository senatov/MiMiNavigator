// PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
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
    @State private var rowRects: [CustomFile.ID: CGRect] = [:]

    var body: some View {
        let stableKey = files.count.hashValue ^ panelSide.hashValue
        
        StableBy(stableKey) {
            FileTableView(
                panelSide: panelSide,
                files: files,
                selectedID: $selectedID,
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
            .coordinateSpace(name: "fileTableSpace")
            .onPreferenceChange(RowRectPreference.self) { value in
                if value != rowRects {
                    rowRects = value
                }
            }
            .animation(nil, value: selectedID)
            .transaction { txn in
                txn.disablesAnimations = true
            }
            .id("PFTS_\(panelSide)")
        }
    }

    // MARK: - Selection handler
    private func handleSelection(_ file: CustomFile) {
        let wasInactive = appState.focusedPanel != panelSide
        if wasInactive {
            log.debug("[SELECT-FLOW] Activating panel <<\(panelSide)>>")
        }
        appState.focusedPanel = panelSide
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
