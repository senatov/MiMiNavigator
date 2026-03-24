// FileTableRowsView.swift
// MiMiNavigator — Renders LazyVStack of file rows with optimized re-rendering.

import FileModelKit
import SwiftUI

struct FileTableRowsView: View {

    @Environment(\.displayScale) private var displayScale
    private var onePixel: CGFloat { 1.0 / displayScale }

    let rows: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: FavPanelSide
    let layout: ColumnLayoutModel
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let handleFileAction: (FileAction, CustomFile) -> Void
    let handleDirectoryAction: (DirectoryAction, CustomFile) -> Void
    let handleMultiSelectionAction: (MultiSelectionAction) -> Void

    var body: some View {
        // Snapshot to avoid multiple binding reads during render
        let currentSelectedID = selectedID
        // Ensure a single visible parent row ("..")
        let displayRows: [CustomFile] = {
            var out: [CustomFile] = []
            out.reserveCapacity(rows.count)
            var seenParent = false
            for f in rows {
                let isParent = isParentRow(f)
                if isParent {
                    if seenParent {
                        continue
                    }
                    seenParent = true
                }
                out.append(f)
            }
            return out
        }()
        VStack(spacing: 0) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(displayRows.enumerated()), id: \.offset) { (i, file) in
                    let isSelected = isRowSelected(file: file, currentSelectedID: currentSelectedID)
                    let isParent = isParentRow(file)
                    SizeAwareRow(
                        id: file.id,
                        isSelected: isSelected,
                        layoutVersion: layout.layoutVersion,
                        sizeVersion: file.sizeVersion,
                        isParent: isParent
                    ) {
                        rowContent(index: i, file: file, isSelected: isSelected)
                            .id(file.id)
                    }
                }
            }
            // Give the last row 1px breathing room inside scroll content so the bottom border won't be clipped.
            Color.clear.frame(height: onePixel)
        }
        .transaction { $0.disablesAnimations = true }
    }

    // MARK: - Selection Check
    private func isRowSelected(file: CustomFile, currentSelectedID: CustomFile.ID?) -> Bool {
        guard let currentSelectedID else { return false }

        // Normal files — match by ID
        if file.id == currentSelectedID {
            return true
        }

        // Parent row has unstable identity, so we detect selection by checking
        // whether selectedID matches any real file. If not — parent is selected.
        // Parent entry ("..") — detect by exclusion (selectedID does not belong to any real file)
        if isParentRow(file) {
            let isRealFileSelected = rows.contains { f in
                !isParentRow(f) && f.id == currentSelectedID
            }
            return !isRealFileSelected
        }

        return false
    }

    // MARK: - Parent Row Detection

    private func isParentRow(_ file: CustomFile) -> Bool {
        file.isParentEntry || file.nameStr == ".."
    }

    // MARK: - Row Content

    @ViewBuilder
    private func rowContent(index: Int, file: CustomFile, isSelected: Bool) -> some View {
        if isParentRow(file) {
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

// MARK: - SizeAwareRow

/// Lightweight row wrapper to avoid full list re-rendering.
/// Uses `sizeVersion` to refresh size column updates while keeping SwiftUI diffs cheap.
struct SizeAwareRow<Content: View>: View, Equatable {
    let id: CustomFile.ID
    let isSelected: Bool
    let layoutVersion: Int
    let sizeVersion: Int
    let isParent: Bool
    @ViewBuilder let content: () -> Content
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.isSelected == rhs.isSelected
            && lhs.layoutVersion == rhs.layoutVersion
            && lhs.sizeVersion == rhs.sizeVersion
            && lhs.isParent == rhs.isParent
    }
    var body: some View {
        content()
    }
}
