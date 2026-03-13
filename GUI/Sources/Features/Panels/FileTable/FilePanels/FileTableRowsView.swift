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
                ForEach(Array(rows.indices), id: \.self) { i in
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

                    // DEBUG logging for selection state (temporary, remove after debugging)
                    let _ = {
                        if file.isParentEntry {
                            print(
                                "[FileTableRowsView] parentRow",
                                "file.id=\(file.id)",
                                "selectedID=\(String(describing: currentSelectedID))",
                                "parentSelectedByKeyboard=\(parentSelectedByKeyboard)",
                                "isSelected=\(isSelected)"
                            )
                        }
                    }()

                    EquatableRow(
                        id: file.id,
                        isSelected: isSelected
                    ) {

                        Group {

                        // Parent directory entry: render as full-width navigation row
                        if file.isParentEntry {

                            let parentName = file.urlValue.lastPathComponent.isEmpty
                                ? file.urlValue.path
                                : file.urlValue.lastPathComponent
                            let visibleItemCount = max(rows.count - 1, 0)
                            let parentSizeText: String = {
                                if let values = try? file.urlValue.resourceValues(forKeys: [.fileAllocatedSizeKey, .totalFileAllocatedSizeKey]),
                                   let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize
                                {
                                    let formatter = ByteCountFormatter()
                                    formatter.countStyle = .file
                                    return formatter.string(fromByteCount: Int64(size))
                                }
                                return ""
                            }()

                            HStack(spacing: 8) {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(isSelected ? .primary : .secondary)

                                Text("..")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Text(parentName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .padding(.leading, 4)

                                Text("(\(visibleItemCount))")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)

                                if !parentSizeText.isEmpty {
                                    Text(parentSizeText)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.28) : Color.clear
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(isSelected ? Color.accentColor.opacity(0.70) : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(file)
                            }
                            .onTapGesture(count: 2) {
                                onDoubleClick(file)
                            }

                        } else {
                            FileRow(
                                index: i,
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
                    }
                }
            }
            .transaction { $0.disablesAnimations = true }  // Disable animations for large lists
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
