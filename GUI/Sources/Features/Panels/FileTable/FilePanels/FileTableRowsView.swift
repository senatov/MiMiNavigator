    // FileTableRowsView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 23.10.2024.
    //  Copyright © 2024-2026 Senatov. All rights reserved.

    import FileModelKit
    import SwiftUI

    // MARK: - Renders LazyVStack of file rows
    struct FileTableRowsView: View {
        let rows: [CustomFile]
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
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    let file = rows[i]
                    let isSelected = currentSelectedID == file.id

                    EquatableRow(
                        id: file.id,
                        isSelected: isSelected
                    ) {
                        FileRow(
                            index: i,
                            file: file,
                            isSelected: isSelected,
                            panelSide: panelSide,
                            layout: layout,
                            onSelect: onSelect,
                            onDoubleClick: onDoubleClick,
                            onFileAction: handleFileAction,
                            onDirectoryAction: handleDirectoryAction,
                            onMultiSelectionAction: handleMultiSelectionAction
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .transaction { $0.disablesAnimations = true }  // Disable animations for large lists
        }
    }

    // MARK: - Equatable wrapper to prevent unnecessary row re-rendering
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
