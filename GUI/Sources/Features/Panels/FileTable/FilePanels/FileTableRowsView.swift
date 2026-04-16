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

    // Centralized helpers for selection and display
    private var currentSelectedID: CustomFile.ID? {
        selectedID
    }

    private var displayRows: [CustomFile] {
        makeDisplayRows(from: rows)
    }

    var body: some View {
        VStack(spacing: 0) {
            rowsStack
            bottomBreathingSpace
        }
        .transaction { $0.disablesAnimations = true }
    }
    // MARK: - View Sections
    private var rowsStack: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(displayRows.enumerated()), id: \.element.id) { index, file in
                sizeAwareRow(index: index, file: file)
            }
        }
    }

    private var bottomBreathingSpace: some View {
        Color.clear.frame(height: onePixel)
    }

    @ViewBuilder
    private func sizeAwareRow(index: Int, file: CustomFile) -> some View {
        let isSelected = isRowSelected(file: file, currentSelectedID: currentSelectedID)
        let isParent = isParentRow(file)

        SizeAwareRow(
            id: file.id,
            isSelected: isSelected,
            layoutVersion: layout.layoutVersion,
            sizeVersion: file.sizeVersion,
            byteSize: file.sizeInBytes,
            modifiedTimestamp: file.modifiedDate?.timeIntervalSince1970 ?? 0,
            isParent: isParent
        ) {
            rowContent(index: index, file: file, isSelected: isSelected)
                .id("\(file.id)#\(file.sizeVersion)#\(file.sizeInBytes)#\(file.modifiedDate?.timeIntervalSince1970 ?? 0)")
        }
    }

    private func makeDisplayRows(from rows: [CustomFile]) -> [CustomFile] {
        var output: [CustomFile] = []
        output.reserveCapacity(rows.count)
        var seenParent = false

        for file in rows {
            let isParent = isParentRow(file)
            if isParent && seenParent {
                continue
            }
            if isParent {
                seenParent = true
            }
            output.append(file)
        }

        return output
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
            return !hasSelectedRealFile(currentSelectedID)
        }

        return false
    }

    private func hasSelectedRealFile(_ selectedID: CustomFile.ID) -> Bool {
        rows.contains { file in
            !isParentRow(file) && file.id == selectedID
        }
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
                file: file,
                isSelected: isSelected,
                parentURL: parentUrl,
                onSelect: onSelect,
                onActivate: onDoubleClick
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
    let byteSize: Int64
    let modifiedTimestamp: TimeInterval
    let isParent: Bool
    @ViewBuilder let content: () -> Content
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.isSelected == rhs.isSelected
            && lhs.layoutVersion == rhs.layoutVersion
            && lhs.sizeVersion == rhs.sizeVersion
            && lhs.byteSize == rhs.byteSize
            && lhs.modifiedTimestamp == rhs.modifiedTimestamp
            && lhs.isParent == rhs.isParent
    }
    var body: some View {
        content()
    }
}
