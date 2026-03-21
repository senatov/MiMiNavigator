// FileTableRowsView.swift
// MiMiNavigator — Renders LazyVStack of file rows with optimized re-rendering.

import FileModelKit
import SwiftUI

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
        let currentSelectedID = selectedID
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                let file = rows[i]
                let isSelected = isRowSelected(file: file, currentSelectedID: currentSelectedID)
                EquatableRow(
                    id: file.id,
                    isSelected: isSelected,
                    layoutVersion: layout.layoutVersion,
                    isParent: file.isParentEntry
                ) {
                    rowContent(index: i, file: file, isSelected: isSelected)
                }
            }
        }
        .transaction { $0.disablesAnimations = true }
    }

    // MARK: - Selection Check

    private func isRowSelected(file: CustomFile, currentSelectedID: CustomFile.ID?) -> Bool {
        if currentSelectedID == file.id { return true }
        if file.isParentEntry && currentSelectedID == file.urlValue.standardizedFileURL.path {
            return true
        }
        return false
    }

    // MARK: - Row Content

    @ViewBuilder
    private func rowContent(index: Int, file: CustomFile, isSelected: Bool) -> some View {
        let _ = log.debug(#function)
        if file.isParentEntry {
            let parentUrl = file.urlValue
            ParentEntryStripView(
                parentUrl: parentUrl,
                file: file,
                isSelected: isSelected,
                onSelect: onSelect,
                onDoubleClick: onDoubleClick
            )
        } else {
            FileRow(
                index: index,
                file: file,
                isSelected: isSelected,
                panelSide: panelSide,
                layout: layout,
                layoutVersion: layout.layoutVersion,
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
