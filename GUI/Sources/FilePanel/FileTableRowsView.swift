//
// FileTableRowsView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// Separate view to simplify type-checking of the main FileTableView.
/// Responsible only for rendering the LazyVStack of rows.
struct FileTableRowsView: View {
    let rows: [(offset: Int, element: CustomFile)]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: PanelSide
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let handleFileAction: (FileAction, CustomFile) -> Void
    let handleDirectoryAction: (DirectoryAction, CustomFile) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(rows, id: \.element.id) { pair in
                EquatableView(value: pair.element.id) {
                    row(for: pair.element, index: pair.offset)
                }
            }
        }
    }

    // MARK: - Row builder
    @ViewBuilder
    private func row(for file: CustomFile, index: Int) -> some View {
        let isSelected = selectedID == file.id
        FileRow(
            index: index,
            file: file,
            isSelected: isSelected,
            panelSide: panelSide,
            onSelect: { tapped in
                log.debug("[SELECT-FLOW] FileTableRowsView.onSelect: \(tapped.nameStr) on <<\(panelSide)>>")
                // Just forward to parent — all logic is centralized in PanelFileTableSection
                onSelect(tapped)
            },
            onDoubleClick: { tapped in
                log.debug("[DOUBLE-CLICK] FileTableRowsView: \(tapped.nameStr) on <<\(panelSide)>>")
                onDoubleClick(tapped)
            },
            onFileAction: { action, f in
                log.debug("FileTableRowsView.onFileAction: \(action)")
                handleFileAction(action, f)
            },
            onDirectoryAction: { action, f in
                log.debug("FileTableRowsView.onDirectoryAction: \(action)")
                handleDirectoryAction(action, f)
            }
        )
        .id(file.id) // Critical for ScrollViewReader.scrollTo() to work
    }
}
