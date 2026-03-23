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
    let isParentFocused: Bool

    @State private var cachedDisplayRows: [CustomFile] = []

    // MARK: - Normalized Rows

    private var displayRows: [CustomFile] {
        cachedDisplayRows
    }

    var body: some View {
        let currentSelectedID = selectedID
        let displayRows = cachedDisplayRows.isEmpty ? normalizedRows(from: rows) : cachedDisplayRows

        VStack(spacing: 0) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(displayRows.indices, id: \.self) { index in
                    let file = displayRows[index]
                    let isParent = isParentRowCandidate(file)
                    let isSelected = isRowSelected(file: file, isParent: isParent, currentSelectedID: currentSelectedID)

                    SizeAwareRow(
                        id: file.id,
                        isSelected: isSelected,
                        layoutVersion: layout.layoutVersion,
                        sizeVersion: file.sizeVersion,
                        isParent: isParent,
                        isParentFocused: isParent ? isParentFocused : false
                    ) {
                        rowContent(index: index, file: file, isSelected: isSelected)
                    }
                }
            }

            // Give the last row 1px breathing room inside scroll content so the bottom border won't be clipped.
            Color.clear
                .frame(height: onePixel)
        }
        .onAppear {
            updateCache()
        }
        .onChange(of: rows) { _, _ in
            updateCache()
        }
        .transaction { $0.disablesAnimations = true }
    }

    private func updateCache() {
        cachedDisplayRows = normalizedRows(from: rows)
    }

    // MARK: - Selection Check

    private func isRowSelected(file: CustomFile, isParent: Bool, currentSelectedID: CustomFile.ID?) -> Bool {
        if currentSelectedID == file.id { return true }
        if isParentSelected(file: file, isParent: isParent, currentSelectedID: currentSelectedID) { return true }
        return false
    }

    private func isParentSelected(file: CustomFile, isParent: Bool, currentSelectedID: CustomFile.ID?) -> Bool {
        guard isParent else { return false }
        return currentSelectedID == file.urlValue.standardizedFileURL.path
    }

    // MARK: - Parent Row Detection

    private func isParentRowCandidate(_ file: CustomFile) -> Bool {
        // Some legacy/restored rows may have name ".." but miss isParentEntry flag.
        if file.isParentEntry { return true }
        return file.nameStr == ".."
    }

    private func normalizedRows(from rows: [CustomFile]) -> [CustomFile] {
        var normalized: [CustomFile] = []
        normalized.reserveCapacity(rows.count)

        var hasParent = false
        for file in rows {
            let isParent = isParentRowCandidate(file)
            if isParent {
                if hasParent {
                    log.debug("[Rows] duplicate parent entry skipped: \(file.nameStr)")
                    continue
                }
                hasParent = true
            }
            normalized.append(file)
        }

        return normalized
    }

    // MARK: - Row Content

    @ViewBuilder
    private func rowContent(index: Int, file: CustomFile, isSelected: Bool) -> some View {
        let isParent = isParentRowCandidate(file)
        if isParent {
            let parentUrl = file.urlValue
            ParentEntryStripView(
                parentUrl: parentUrl,
                file: file,
                isSelected: isSelected,
                onSelect: onSelect,
                onDoubleClick: onDoubleClick,
                isFocused: isParentFocused
            )
            .focusable(true)
            .animation(nil, value: isParentFocused)
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
    let isParentFocused: Bool
    @ViewBuilder let content: () -> Content

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.isSelected == rhs.isSelected
            && lhs.layoutVersion == rhs.layoutVersion
            && lhs.sizeVersion == rhs.sizeVersion
            && lhs.isParent == rhs.isParent
            && lhs.isParentFocused == rhs.isParentFocused
    }

    var body: some View {
        content()
    }
}
