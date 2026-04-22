// FileTableRowsView.swift
// MiMiNavigator — Renders LazyVStack of file rows with optimized re-rendering.
//   Parent ".." strip is now a separate panel (ParentNavigationStripPanel) —
//   this view only renders real filesystem entries.

import FileModelKit
import SwiftUI

struct FileTableRowsView: View {

    private enum SelectionOverlayMetrics {
        static let cornerRadius: CGFloat = 6
        static let horizontalInset: CGFloat = 1
        static let fillTopInset: CGFloat = 1
        static let fillBottomInset: CGFloat = 1
        static let borderTopInset: CGFloat = 1
        static let borderBottomInset: CGFloat = 1
        static let rowsTopInset: CGFloat = 2
    }

    private struct SelectionOverlayLayout {
        let yOffset: CGFloat
        let visibleHeight: CGFloat

        init(rowYOffset: CGFloat, rowHeight: CGFloat, topInset: CGFloat, bottomInset: CGFloat) {
            self.yOffset = rowYOffset + topInset
            self.visibleHeight = max(0, rowHeight - topInset - bottomInset)
        }
    }

    private static let selectionSpring = Animation.interpolatingSpring(
        mass: 0.22,
        stiffness: 240,
        damping: 24,
        initialVelocity: 0
    )

    @Environment(AppState.self) private var appState
    @Environment(\.displayScale) private var displayScale
    private var onePixel: CGFloat { 1.0 / displayScale }
    @State private var colorStore = ColorThemeStore.shared

    let rows: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: FavPanelSide
    let layout: ColumnLayoutModel
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let handleFileAction: (FileAction, CustomFile) -> Void
    let handleDirectoryAction: (DirectoryAction, CustomFile) -> Void
    let handleMultiSelectionAction: (MultiSelectionAction) -> Void


    private var currentSelectedID: CustomFile.ID? {
        selectedID
    }


    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }


    private var selectedDisplayIndex: Int? {
        rows.firstIndex { $0.id == currentSelectedID }
    }


    private var selectedRowYOffset: CGFloat? {
        guard let selectedDisplayIndex else { return nil }
        return SelectionOverlayMetrics.rowsTopInset
            + CGFloat(selectedDisplayIndex) * FilePanelStyle.rowHeight
    }


    private var selectedRowHeight: CGFloat? {
        guard selectedDisplayIndex != nil else { return nil }
        return FilePanelStyle.rowHeight
    }


    private var selectionFillLayout: SelectionOverlayLayout? {
        guard let selectedRowYOffset, let selectedRowHeight else { return nil }
        return SelectionOverlayLayout(
            rowYOffset: selectedRowYOffset,
            rowHeight: selectedRowHeight,
            topInset: SelectionOverlayMetrics.fillTopInset,
            bottomInset: SelectionOverlayMetrics.fillBottomInset
        )
    }


    private var selectionBorderLayout: SelectionOverlayLayout? {
        guard let selectedRowYOffset, let selectedRowHeight else { return nil }
        return SelectionOverlayLayout(
            rowYOffset: selectedRowYOffset,
            rowHeight: selectedRowHeight,
            topInset: SelectionOverlayMetrics.borderTopInset,
            bottomInset: SelectionOverlayMetrics.borderBottomInset
        )
    }


    var body: some View {
        VStack(spacing: 0) {
            rowsLayer
            bottomBreathingSpace
        }
    }

    // MARK: - View Sections

    private var rowsLayer: some View {
        ZStack(alignment: .topLeading) {
            selectionFillOverlay
            rowsStack
            selectionBorderOverlay
        }
        .animation(Self.selectionSpring, value: selectedDisplayIndex)
        .animation(Self.selectionSpring, value: selectedRowYOffset)
    }


    private var rowsStack: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, file in
                sizeAwareRow(index: index, file: file)
            }
        }
        .padding(.top, SelectionOverlayMetrics.rowsTopInset)
        .transaction { $0.disablesAnimations = true }
    }


    @ViewBuilder
    private var selectionFillOverlay: some View {
        if let layout = selectionFillLayout {
            RoundedRectangle(cornerRadius: SelectionOverlayMetrics.cornerRadius, style: .continuous)
                .fill(isActivePanel ? colorStore.activeTheme.selectionActive : colorStore.activeTheme.selectionInactive)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: layout.visibleHeight)
                .padding(.horizontal, SelectionOverlayMetrics.horizontalInset)
                .offset(y: layout.yOffset)
                .allowsHitTesting(false)
        }
    }


    @ViewBuilder
    private var selectionBorderOverlay: some View {
        if let layout = selectionBorderLayout {
            RoundedRectangle(cornerRadius: SelectionOverlayMetrics.cornerRadius, style: .continuous)
                .strokeBorder(selectionBorderColor, lineWidth: selectionBorderLineWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: layout.visibleHeight)
                .padding(.horizontal, SelectionOverlayMetrics.horizontalInset)
                .offset(y: layout.yOffset)
                .allowsHitTesting(false)
        }
    }


    private var selectionBorderColor: Color {
        let base = colorStore.activeTheme.selectionBorder
        return isActivePanel ? base : base.opacity(0.5)
    }


    private var selectionBorderLineWidth: CGFloat {
        max(onePixel, colorStore.activeTheme.selectionLineWidth)
    }


    private var bottomBreathingSpace: some View {
        Color.clear.frame(height: onePixel)
    }


    @ViewBuilder
    private func sizeAwareRow(index: Int, file: CustomFile) -> some View {
        let isSelected = file.id == currentSelectedID

        SizeAwareRow(
            id: file.id,
            isSelected: isSelected,
            layoutVersion: layout.layoutVersion,
            sizeVersion: file.sizeVersion,
            byteSize: file.sizeInBytes,
            modifiedTimestamp: file.modifiedDate?.timeIntervalSince1970 ?? 0,
            isParent: false
        ) {
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
            .id("\(file.id)#\(file.sizeVersion)#\(file.sizeInBytes)#\(file.modifiedDate?.timeIntervalSince1970 ?? 0)")
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
