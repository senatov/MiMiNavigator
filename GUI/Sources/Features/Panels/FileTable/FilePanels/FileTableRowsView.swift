    // FileTableRowsView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 23.10.2024.
    //  Copyright © 2024-2026 Senatov. All rights reserved.

    import FileModelKit
    import SwiftUI

    // MARK: - Renders LazyVStack of file rows
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
            let currentSelectedID = selectedID  // Capture once to avoid repeated Binding access
            LazyVStack(alignment: .leading, spacing: 0) {
                // Avoid allocating a new Array for large directories (10k+ items).
                // `rows.indices` is already a RandomAccessCollection and works directly with ForEach.
                ForEach(rows.indices, id: \.self) { i in
                    let file = rows[i]

                    // Keyboard navigation sometimes represents the ".." selection as nil
                    // (because it is a synthetic entry and not a real file in the model).
                    // We therefore treat the parent row as selected if selectedID is nil
                    // and this row is the parent entry.
                    let parentSelectedByKeyboard =
                        file.isParentEntry &&
                        currentSelectedID == file.urlValue.standardizedFileURL.path

                    let isSelected =
                        currentSelectedID == file.id ||
                        parentSelectedByKeyboard

                    // Debug logging removed: printing inside SwiftUI row rendering
                    // causes significant slowdown when directories contain thousands of files.

                    EquatableRow(
                        id: file.id,
                        isSelected: isSelected,
                        isParent: file.isParentEntry
                    ) {

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
                            fileRowView(
                                index: i,
                                file: file,
                                isSelected: isSelected
                            )
                        }
                    }
                }
            }
            .transaction { $0.disablesAnimations = true }  // Disable animations for large lists
        }



        // MARK: - File row renderer
        @ViewBuilder
        private func fileRowView(
            index: Int,
            file: CustomFile,
            isSelected: Bool
        ) -> some View {

            FileRow(
                index: index,
                file: file,
                isSelected: isSelected,
                panelSide: panelSide,
                layout: layout,
                onSelect: onSelect,
                onDoubleClick: onDoubleClick,
                onFileAction: handleFileAction,
                onDirectoryAction: handleDirectoryAction,
                onMultiSelectionAction: handleMultiSelectionAction
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Equatable wrapper to prevent unnecessary row re-rendering
    struct EquatableRow<Content: View>: View, Equatable {
        let id: CustomFile.ID
        let isSelected: Bool
        var isParent: Bool = false
        @ViewBuilder let content: () -> Content

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id && lhs.isSelected == rhs.isSelected
        }

        var body: some View {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    isParent
                        ? Color.clear   // ParentDirectoryRow manages its own background + border
                        : (isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
                )
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
    // MARK: - body
    var body: some View {
        let parentName = file.urlValue.lastPathComponent.isEmpty
            ? file.urlValue.path
            : file.urlValue.lastPathComponent
        let visibleItemCount = max(rowsCount - 1, 0)
        let clrBlue   = Color(#colorLiteral(red: 0.10, green: 0.30, blue: 0.65, alpha: 1))
        let clrBg     = Color(#colorLiteral(red: 0.98, green: 0.96, blue: 0.90, alpha: 1))
        let clrBgHov  = Color(#colorLiteral(red: 1.0,  green: 0.98, blue: 0.72, alpha: 1))
        let clrBgSel  = Color(#colorLiteral(red: 0.98, green: 0.94, blue: 0.55, alpha: 1))
        let isFocused = appState.focusedPanel == panelSide
        let theme = colorStore.activeTheme
        let borderColor = isFocused ? theme.panelBorderActive : theme.panelBorderInactive
        let borderW = theme.panelBorderWidth
        HStack(spacing: 8) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .resizable()
                .frame(width: 14, height: 13)
                .foregroundStyle(clrBlue)
            Text("..")
                .font(.system(size: 13, weight: .ultraLight))
                .foregroundStyle(clrBlue)
            Text(parentName)
                .font(.system(size: 13, weight: .ultraLight))
                .foregroundStyle(clrBlue)
                .lineLimit(1)
            Text("(\(visibleItemCount))")
                .font(.system(size: 12, weight: .ultraLight))
                .foregroundStyle(clrBlue.opacity(0.75))
            Spacer(minLength: 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .background(
            ZStack {
                (isSelected ? clrBgSel : (isHovering ? clrBgHov : clrBg))
                ParentRowInsetBorder(borderColor: borderColor, borderWidth: borderW)
            }
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onSelect(file) }
        .onTapGesture(count: 2) { onDoubleClick(file) }
    }
}

// MARK: - ParentRowInsetBorder
/// Draws a subtle "inset" (recessed groove) effect around the parent row.
/// Top and side edges get a slightly darker line (shadow),
/// bottom edge gets a lighter line (highlight) — classic embossed look.
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
