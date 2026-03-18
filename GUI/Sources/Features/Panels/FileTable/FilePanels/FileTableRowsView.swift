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
            if file.isParentEntry {
                ParentDirectoryRow(
                    file: file,
                    isSelected: isSelected,
                    rowsCount: rows.count,
                    panelSide: panelSide,
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

    // MARK: - EquatableRow

    struct EquatableRow<Content: View>: View, Equatable {

        let id: CustomFile.ID
        let isSelected: Bool
        let layoutVersion: Int
        var isParent: Bool = false
        @ViewBuilder let content: () -> Content

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id &&
            lhs.isSelected == rhs.isSelected &&
            lhs.layoutVersion == rhs.layoutVersion
        }

        var body: some View {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(rowBackground)
        }

        private var rowBackground: Color {
            if isParent { return .clear }
            return isSelected ? Color.accentColor.opacity(0.20) : .clear
        }
    }

    // MARK: - ParentDirectoryRow

    private struct ParentDirectoryRow: View {

        let file: CustomFile
        let isSelected: Bool
        let rowsCount: Int
        let panelSide: PanelSide
        let onSelect: (CustomFile) -> Void
        let onDoubleClick: (CustomFile) -> Void

        @State private var isHovering = false
        @Environment(AppState.self) private var appState

        private var colorStore: ColorThemeStore { ColorThemeStore.shared }

        private var parentName: String {
            file.urlValue.lastPathComponent.isEmpty
                ? file.urlValue.path
                : file.urlValue.lastPathComponent
        }

        private var visibleItemCount: Int { max(rowsCount - 1, 0) }
        private var isFocused: Bool { appState.focusedPanel == panelSide }

        // Colors
        private let textColor = Color(#colorLiteral(red: 0.10, green: 0.30, blue: 0.65, alpha: 1))
        private let bgNormal = Color(#colorLiteral(red: 0.98, green: 0.96, blue: 0.90, alpha: 1))
        private let bgHover = Color(#colorLiteral(red: 1.0, green: 0.98, blue: 0.72, alpha: 1))
        private let bgSelected = Color(#colorLiteral(red: 0.98, green: 0.94, blue: 0.55, alpha: 1))

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .resizable()
                    .frame(width: 14, height: 13)
                    .foregroundStyle(textColor)

                Text("..")
                    .font(.system(size: 13, weight: .ultraLight))
                    .foregroundStyle(textColor)

                Text(parentName)
                    .font(.system(size: 13, weight: .ultraLight))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Text("(\(visibleItemCount))")
                    .font(.system(size: 12, weight: .ultraLight))
                    .foregroundStyle(textColor.opacity(0.75))

                Spacer(minLength: 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(backgroundView)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture { onSelect(file) }
            .onTapGesture(count: 2) { onDoubleClick(file) }
        }

        private var backgroundView: some View {
            let theme = colorStore.activeTheme
            let borderColor = isFocused ? theme.panelBorderActive : theme.panelBorderInactive

            return ZStack {
                backgroundColor
                ParentRowInsetBorder(borderColor: borderColor, borderWidth: theme.panelBorderWidth)
            }
        }

        private var backgroundColor: Color {
            if isSelected { return bgSelected }
            if isHovering { return bgHover }
            return bgNormal
        }
    }

    // MARK: - ParentRowInsetBorder

    private struct ParentRowInsetBorder: View {

        let borderColor: Color
        let borderWidth: CGFloat

        var body: some View {
            ZStack {
                Rectangle()
                    .strokeBorder(borderColor.opacity(0.55), lineWidth: borderWidth)

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(borderColor.opacity(0.35))
                        .frame(height: borderWidth)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color.white.opacity(0.45))
                        .frame(height: max(borderWidth * 0.6, 0.5))
                }
            }
        }
    }
