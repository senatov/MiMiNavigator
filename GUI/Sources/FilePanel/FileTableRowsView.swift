//
//  FileTableRowsView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Separate view to simplify type-checking of the main FileTableView.
/// Responsible only for rendering the LazyVStack of rows.
struct FileTableRowsView: View {
    @EnvironmentObject var appState: AppState
    let rows: [(offset: Int, element: CustomFile)]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: PanelSide
    let onSelect: (CustomFile) -> Void
    let handleFileAction: (FileAction, CustomFile) -> Void
    let handleDirectoryAction: (DirectoryAction, CustomFile) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows, id: \.element.id) { pair in
                row(for: pair.element, index: pair.offset)
            }
        }
        .animation(nil, value: selectedID)  // disable implicit animation for smoother selection
    }

    // MARK: - Row builder
    @ViewBuilder
    private func row(for file: CustomFile, index: Int) -> some View {
        let isSelected = selectedID == file.id
        ZStack(alignment: .leading) {
            // Unified full-width row background
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(FilePanelStyle.yellowSelRowFill))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                FilePanelStyle.blueSymlinkDirNameColor,
                                lineWidth: FilePanelStyle.selectedBorderWidth)
                    )
            }

            // Actual row content (name, size, date columns)
            FileRow(
                index: index,
                file: file,
                isSelected: isSelected,
                panelSide: panelSide,
                onSelect: { tapped in
                    // prevent redundant state changes
                    guard selectedID != tapped.id else { return }
                    selectedID = tapped.id
                    appState.focusedPanel = panelSide
                    onSelect(tapped)
                    log.debug("Row tapped: \(tapped.nameStr) [\(tapped.id)] on <<\(panelSide)>>")
                },
                onFileAction: { action, f in
                    handleFileAction(action, f)
                },
                onDirectoryAction: { action, f in
                    handleDirectoryAction(action, f)
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())  // allow full-row click
        .id("\(panelSide)_\(file.id)")  // stable ID per file
    }
}
