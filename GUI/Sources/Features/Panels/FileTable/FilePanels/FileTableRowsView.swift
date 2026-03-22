// FileTableRowsView.swift
// MiMiNavigator — Renders LazyVStack of file rows with optimized re-rendering.

import FileModelKit
import SwiftUI

struct FileTableRowsView: View {

    @Environment(\.displayScale) private var displayScale

    private var onePixel: CGFloat { 1.0 / displayScale }

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

        // Keep exactly one parent entry even if legacy/restored ".." row sneaks in without the flag.
        let displayRows: [CustomFile] = {
            var out: [CustomFile] = []
            out.reserveCapacity(rows.count)

            var seenParent = false
            for f in rows {
                let isParent = isParentRowCandidate(f)
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
                ForEach(Array(displayRows.enumerated()), id: \.element.id) { (i, file) in
                    let isSelected = isRowSelected(file: file, currentSelectedID: currentSelectedID)
                    let isParent = isParentRowCandidate(file)

                    SizeAwareRow(
                        id: file.id,
                        isSelected: isSelected,
                        layoutVersion: layout.layoutVersion,
                        sizeVersion: file.sizeVersion,
                        isParent: isParent
                    ) {
                        rowContent(index: i, file: file, isSelected: isSelected)
                    }
                }
            }

            // Give the last row 1px breathing room inside scroll content so the bottom border won't be clipped.
            Color.clear
                .frame(height: onePixel)
        }
        .transaction { $0.disablesAnimations = true }
    }

    // MARK: - Selection Check

    private func isRowSelected(file: CustomFile, currentSelectedID: CustomFile.ID?) -> Bool {
        if currentSelectedID == file.id { return true }

        if isParentRowCandidate(file),
            currentSelectedID == file.urlValue.standardizedFileURL.path
        {
            return true
        }

        return false
    }

    // MARK: - Parent Row Detection

    private func isParentRowCandidate(_ file: CustomFile) -> Bool {
        // Some legacy/restored rows may have name ".." but miss isParentEntry flag.
        if file.isParentEntry { return true }
        return file.nameStr == ".."
    }

    // MARK: - Row Content

    @ViewBuilder
    private func rowContent(index: Int, file: CustomFile, isSelected: Bool) -> some View {
        if isParentRowCandidate(file) {
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
