//
//  FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct FileTableView: View {
    @EnvironmentObject var appState: AppState
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onSelect: (CustomFile) -> Void
    // MARK: - Sorting State
    private enum SortKey { case name, size, date }
    @State private var sortKey: SortKey = .name
    @State private var sortAscending: Bool = true

    // MARK: -
    private var sortedFiles: [CustomFile] {
        let base = files
        switch sortKey {
        case .name:
            return base.sorted { lhs, rhs in
                let l = lhs.nameStr.lowercased()
                let r = rhs.nameStr.lowercased()
                return sortAscending ? (l < r) : (l > r)
            }

        case .size:
            // сортировка по отображаемой строке размера как безопасный дефолт
            return base.sorted { lhs, rhs in
                let l = lhs.fileObjTypEnum
                let r = rhs.fileObjTypEnum
                return sortAscending ? (l < r) : (l > r)
            }

        case .date:
            // сортировка по отображаемой строке даты как безопасный дефолт
            return base.sorted { lhs, rhs in
                let l = lhs.modifiedDateFormatted
                let r = rhs.modifiedDateFormatted
                return sortAscending ? (l < r) : (l > r)
            }
        }
    }

    // MARK: - Initializer
    var body: some View {
        log.info(#function + " with \(files.count) files, selectedID: \(String(describing: selectedID))")
        return ScrollView {
            VStack(spacing: 0) {
                // File Table header
                HStack(spacing: 8) {
                    // Name header (sortable)
                    HStack(spacing: 4) {
                        Text("Name")
                            .font(.subheadline)
                        if sortKey == .name {
                            Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        log.info("Tapped Name header for sorting")
                        if sortKey == .name {
                            sortAscending.toggle()
                            appState.updateSorting(key: .name, ascending: !appState.sortAscending)
                        } else {
                            sortKey = .name; sortAscending = true
                            appState.updateSorting(key: .name, ascending: appState.sortAscending)
                        }
                    }
                    // vertical separator
                    Rectangle().frame(width: 1)
                        .foregroundColor(Color.secondary.opacity(0.25))
                        .padding(.vertical, 2)
                    // Size header (sortable)
                    HStack(spacing: 4) {
                        Text("Size")
                            .font(.subheadline)
                        if sortKey == .size {
                            Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
                        }
                    }
                    .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        log.info("Size header tapped")
                        if sortKey == .size {
                            sortAscending.toggle()
                            appState.updateSorting(key: .size, ascending: !appState.sortAscending)
                        } else {
                            sortKey = .size; sortAscending = true
                            appState.updateSorting(key: .size, ascending: appState.sortAscending)
                        }
                    }
                    // vertical separator
                    Rectangle().frame(width: 1)
                        .foregroundColor(Color.secondary.opacity(0.25))
                        .padding(.vertical, 2)
                    // Date header (sortable)
                    HStack(spacing: 4) {
                        Text("Date")
                            .font(.subheadline)
                        if sortKey == .date {
                            Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
                        }
                    }
                    .frame(width: FilePanelStyle.modifiedColumnWidth + 10, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        log.info("Date header tapped")
                        if sortKey == .date {
                            sortAscending.toggle()
                            appState.updateSorting(key: .date, ascending: !appState.sortAscending)
                        } else {
                            sortKey = .date; sortAscending = true
                            appState.updateSorting(key: .date, ascending: appState.sortAscending)
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .frame(height: 0.6)
                        .foregroundColor(FilePanelStyle.symlinkDirNameColor.opacity(0.15)),
                    alignment: .bottom
                )
            }
            LazyVStack(spacing: 0) {
                ForEach(Array(sortedFiles.enumerated()), id: \.element.id) { index, file in
                    let isSel = (selectedID == file.id)
                    ZStack(alignment: .leading) {
                        // Zebra background stripes (Finder-like)
                        (index.isMultiple(of: 2) ? Color.white : Color.gray.opacity(0.06))
                            .allowsHitTesting(false)
                        if isSel {
                            Rectangle()
                                .fill(FilePanelStyle.selectedRowFill)
                                .overlay(
                                    Rectangle()
                                        .stroke(FilePanelStyle.selectedRowStroke, lineWidth: 0.8)
                                )
                                .allowsHitTesting(false)
                        }
                        HStack(alignment: .center, spacing: 8) {
                            // Name column (expands)
                            FileRowView(file: file, isSelected: isSel)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // vertical separator
                            Rectangle().frame(width: 1)
                                .foregroundColor(Color.secondary.opacity(0.15))
                                .padding(.vertical, 2)

                            // Size column
                            Text(file.fileObjTypEnum)
                                .foregroundColor(Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1)))
                                .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading)

                            // vertical separator
                            Rectangle().frame(width: 1)
                                .foregroundColor(Color.secondary.opacity(0.15))
                                .padding(.vertical, 2)

                            // Date column
                            Text(file.modifiedDateFormatted)
                                .foregroundColor(Color(#colorLiteral(red: 0.3098039329, green: 0.01568627544, blue: 0.1294117719, alpha: 1)))
                                .frame(width: FilePanelStyle.modifiedColumnWidth + 10, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                selectedID = file.id
                                onSelect(file)
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .stroke(FilePanelStyle.symlinkDirNameColor, lineWidth: FilePanelStyle.selectedBorderWidth)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        )
    }
}
