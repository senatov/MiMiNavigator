// FileTableRowsView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024-2026 Senatov. All rights reserved.

import SwiftUI
import FileModelKit

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
        LazyVStack(spacing: 0) {
            ForEach(rows, id: \.element.id) { pair in
                StableKeyView(pair.element.id) {
                    row(for: pair.element, index: pair.offset)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for file: CustomFile, index: Int) -> some View {
        let isSelected = selectedID == file.id
        FileRow(
            index: index,
            file: file,
            isSelected: isSelected,
            panelSide: panelSide,
            layout: layout,
            onSelect: { tapped in onSelect(tapped) },
            onDoubleClick: { tapped in onDoubleClick(tapped) },
            onFileAction: { action, f in handleFileAction(action, f) },
            onDirectoryAction: { action, f in handleDirectoryAction(action, f) },
            onMultiSelectionAction: { action in handleMultiSelectionAction(action) }
        )
        .id(file.id)
    }
}
