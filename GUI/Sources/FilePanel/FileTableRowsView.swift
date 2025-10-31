//
//  FileTableRowsView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - EquatableView wrapper to prevent redundant row recomputation
private struct EquatableView<Value: Hashable, Content: View>: View {
    let value: Value
    let content: () -> Content
    @MainActor var body: some View { content().id(value) }
}

/// Separate view to simplify type-checking of the main FileTableView.
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
        ScrollViewReader { proxy in
            LazyVStack(spacing: 0) {
                ForEach(rows, id: \.element.id) { pair in
                    EquatableView(value: pair.element.id) {
                        row(for: pair.element, index: pair.offset)
                    }
                }
            }
        }
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
                    selectedID = tapped.id
                    appState.focusedPanel = panelSide
                    onSelect(tapped)
                    if Int.random(in: 0..<8) == 0 {  // sample roughly every 1/8 taps
                        log.debug("Row tapped: \(tapped.nameStr) [\(tapped.id)] on <<\(panelSide)>>")
                    }
                },
                onFileAction: { action, f in
                    log.debug(#function)
                    handleFileAction(action, f)
                },
                onDirectoryAction: { action, f in
                    log.debug(#function)
                    handleDirectoryAction(action, f)
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())  // allows clicks across entire row width
        .drawingGroup()
        .id("\(panelSide)_\(String(describing: file.id))")
    }
}
