    // FileTableRowsView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 23.10.2024.
    //  Copyright © 2024-2026 Senatov. All rights reserved.

    import FileModelKit
    import SwiftUI

    // MARK: - Renders LazyVStack of file rows
    struct FileTableRowsView: View {
        let rows: [(offset: Int, element: CustomFile)]
        @Binding var selectedID: CustomFile.ID?
        let panelSide: PanelSide
        let layout: ColumnLayoutModel
        let onSelect: (CustomFile) -> Void
        let onDoubleClick: (CustomFile) -> Void
        let handleFileAction: (FileAction, CustomFile) -> Void
        let handleDirectoryAction: (DirectoryAction, CustomFile) -> Void
        let handleMultiSelectionAction: (MultiSelectionAction) -> Void

        var body: some View {
            let currentSelectedID = selectedID  // Capture once to avoid repeated Binding access
            LazyVStack(spacing: 0) {
                ForEach(rows, id: \.element.id) { pair in
                    let isSelected = currentSelectedID == pair.element.id

                    EquatableRow(
                        id: pair.element.id,
                        isSelected: isSelected
                    ) {
                        FileRow(
                            index: pair.offset,
                            file: pair.element,
                            isSelected: isSelected,
                            panelSide: panelSide,
                            layout: layout,
                            onSelect: { tapped in onSelect(tapped) },
                            onDoubleClick: { tapped in onDoubleClick(tapped) },
                            onFileAction: { action, f in handleFileAction(action, f) },
                            onDirectoryAction: { action, f in handleDirectoryAction(action, f) },
                            onMultiSelectionAction: { action in handleMultiSelectionAction(action) }
                        )
                    }
                }
            }
            .drawingGroup(opaque: false)
            .transaction { $0.disablesAnimations = true }  // Disable animations for large lists
        }
    }

    // MARK: - Equatable wrapper to prevent unnecessary row re-rendering
    @MainActor
    struct EquatableRow<Content: View>: View, Equatable {
        let id: CustomFile.ID
        let isSelected: Bool
        let content: () -> Content

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id && lhs.isSelected == rhs.isSelected
        }

        var body: some View {
            content()
        }
    }
