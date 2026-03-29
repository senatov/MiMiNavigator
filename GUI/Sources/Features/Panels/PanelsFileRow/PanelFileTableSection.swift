// PanelFileTableSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.

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
    let panelSide: FavPanelSide
    let onPanelTap: (FavPanelSide) -> Void
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
        panelSide: FavPanelSide,
        onPanelTap: @escaping (FavPanelSide) -> Void,
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
                    // set focus
                    if appState.focusedPanel != panelSide {
                        appState.focusedPanel = panelSide
                    }
                    // plain click anywhere on panel → clear marks if no modifier keys held
                    let mods = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                        .subtracting([.function, .numericPad])
                    let isPlain = mods.isEmpty || mods == .capsLock
                    if isPlain && appState.markedCount(for: panelSide) > 0 {
                        appState.unmarkAll(on: panelSide)
                        log.debug("[PanelFileTableSection] tap → marks nuked on \(panelSide)")
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
            log.debug("[PanelFileTableSection] activating panel on selection: \(panelSide)")
            onPanelTap(panelSide)
        }

        log.debug("[PanelFileTableSection] handleSelection: \(file.nameStr)")

        if appState.focusedPanel != panelSide {
            appState.focusedPanel = panelSide
        }

        // IMPORTANT: update selectedID immediately so SwiftUI highlight updates
        selectedID = file.id
        // Notify listeners
        notifyWillSelect(file)
        // Forward to external selection logic (SelectionManager / AppState)
        onSelect(file)
    }

    private func notifyWillSelect(_ file: CustomFile) {
        log.debug(#function)
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
