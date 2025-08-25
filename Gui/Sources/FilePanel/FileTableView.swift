//
//  FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct FileTableView: View {
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onSelect: (CustomFile) -> Void

    // MARK: - Sorting State
    private enum SortKey { case name, size, date }
    @State private var sortKey: SortKey = .name
    @State private var sortAscending: Bool = true

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
                let l = lhs.formattedSize
                let r = rhs.formattedSize
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
                        if sortKey == .name {
                            sortAscending.toggle()
                        } else {
                            sortKey = .name; sortAscending = true
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
                        if sortKey == .size {
                            sortAscending.toggle()
                        } else {
                            sortKey = .size; sortAscending = true
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
                        if sortKey == .date {
                            sortAscending.toggle()
                        } else {
                            sortKey = .date; sortAscending = true
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.secondary),
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
                                .fill(Color(#colorLiteral(red: 1.0, green: 1.0, blue: 0.9, alpha: 1)))
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(#colorLiteral(red: 1.0, green: 0.6, blue: 0.0, alpha: 1)), lineWidth: 1)
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
                            Text(file.formattedSize)
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
        .border(Color.secondary)
    }
}
