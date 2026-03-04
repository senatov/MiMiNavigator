// PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Feature flag: use NSTableView for large directories
/// When true, uses high-performance NSTableView instead of SwiftUI LazyVStack.
/// NSTableView handles 100k+ files without lag.
private let useNSTableView = false  // Back to SwiftUI

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
    // Use singleton ColumnLayoutStore — avoids recreating ColumnLayoutModel on every SwiftUI rebuild
    private var columnLayout: ColumnLayoutModel {
        ColumnLayoutStore.shared.layout(for: panelSide)
    }

    // MARK: - Init
    init(
        files: [CustomFile],
        selectedID: Binding<CustomFile.ID?>,
        panelSide: PanelSide,
        onPanelTap: @escaping (PanelSide) -> Void,
        onSelect: @escaping (CustomFile) -> Void,
        onDoubleClick: @escaping (CustomFile) -> Void
    ) {
        self.files = files
        self._selectedID = selectedID
        self.panelSide = panelSide
        self.onPanelTap = onPanelTap
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
    }

    var body: some View {
        Group {
            if useNSTableView {
                // High-performance NSTableView for large directories
                FileTableViewHybrid(
                    panelSide: panelSide,
                    files: files,
                    filesVersion: panelSide == .left ? appState.leftFilesVersion : appState.rightFilesVersion,
                    selectedID: $selectedID,
                    layout: columnLayout,
                    onSelect: handleSelection,
                    onDoubleClick: onDoubleClick
                )
            } else {
                // Original SwiftUI implementation
                FileTableView(
                    panelSide: panelSide,
                    files: files,
                    selectedID: $selectedID,
                    layout: columnLayout,
                    onSelect: handleSelection,
                    onDoubleClick: onDoubleClick
                )
            }
        }
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
