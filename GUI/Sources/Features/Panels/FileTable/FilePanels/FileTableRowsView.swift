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
                        isSelected: isSelected
                    ) {

                        if file.isParentEntry {
                            parentRowView(
                                file: file,
                                isSelected: isSelected,
                                rowsCount: rows.count
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

        // MARK: - Parent row renderer (kept outside body for clarity and logging)
        @ViewBuilder
        private func parentRowView(
            file: CustomFile,
            isSelected: Bool,
            rowsCount: Int
        ) -> some View {

            let parentName = file.urlValue.lastPathComponent.isEmpty
                ? file.urlValue.path
                : file.urlValue.lastPathComponent

            let visibleItemCount = max(rowsCount - 1, 0)

            // Avoid expensive filesystem metadata calls during list rendering.
            let parentSizeText: String = ""

            let clrBlue  = Color(#colorLiteral(red: 0.20, green: 0.40, blue: 0.75, alpha: 1))
            let clrBg    = Color(#colorLiteral(red: 1.0,  green: 0.98, blue: 0.82, alpha: 1))
            let clrBgSel = Color(#colorLiteral(red: 0.95, green: 0.90, blue: 0.60, alpha: 1))
            HStack(spacing: 6) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .resizable()
                    .frame(width: 12, height: 11)
                    .foregroundStyle(clrBlue)
                Text("..")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(clrBlue)
                Text(parentName)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(clrBlue)
                    .lineLimit(1)
                Text("(\(visibleItemCount))")
                    .font(.system(size: 10, weight: .ultraLight))
                    .foregroundStyle(clrBlue.opacity(0.7))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            .background(isSelected ? clrBgSel : clrBg)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(file)
            }
            .onTapGesture(count: 2) {
                onDoubleClick(file)
            }
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
        @ViewBuilder let content: () -> Content

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id && lhs.isSelected == rhs.isSelected
        }

        var body: some View {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.20)
                        : Color.clear
                )
        }
    }
