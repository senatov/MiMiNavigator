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
    let panelSide: PanelSide
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onSelect: (CustomFile) -> Void
        // MARK: - Sorting State
    private enum SortKey { case name, size, date }
    @State private var sortKey: SortKey = .name
    @State private var sortAscending: Bool = true

        // MARK: - Sorting comparator extracted to help the type-checker
    private func compare(_ a: CustomFile, _ b: CustomFile) -> Bool {
        let aIsFolder = a.isDirectory || a.isSymbolicDirectory
        let bIsFolder = b.isDirectory || b.isSymbolicDirectory
        if aIsFolder != bIsFolder { return aIsFolder && !bIsFolder }
        switch sortKey {
        case .name:
            let cmp = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
            return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        case .size:
            let lhs: Int64 = a.sizeInBytes
            let rhs: Int64 = b.sizeInBytes
            if lhs != rhs { return sortAscending ? (lhs < rhs) : (lhs > rhs) }
            return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
        case .date:
            let lhs = a.modifiedDate ?? Date.distantPast
            let rhs = b.modifiedDate ?? Date.distantPast
            if lhs != rhs { return sortAscending ? (lhs < rhs) : (lhs > rhs) }
            return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
        }
    }

        // MARK: -
    private var sortedFiles: [CustomFile] {
            // Always sort directories first, then apply selected column sort
        log.info(#function + " for side \(panelSide), sorting by \(sortKey), ascending: \(sortAscending)")
        let base: [CustomFile] = files
        let sorted = base.sorted(by: compare)
        return sorted
    }

        // MARK: - Row content extracted to reduce view-builder complexity
    @ViewBuilder
    private func rowContent(file: CustomFile, isSel: Bool, index: Int) -> some View {
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
    }

        // MARK: - Initializer
    var body: some View {
        log.info(#function + "side: \(panelSide) with \(files.count) files, selectedID: \(String(describing: selectedID)))")
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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
                        log.info("Name header tapped on side: \(panelSide)")
                        appState.focusedPanel = panelSide
                        if sortKey == .name {
                            sortAscending.toggle()
                        } else {
                            sortKey = .name
                            sortAscending = true
                        }
                        appState.updateSorting(key: .name, ascending: sortAscending)
                    }
                        // vertical separator
                    Rectangle().frame(width: 1)
                        .foregroundColor(Color.secondary.opacity(0.25))
                        .padding(.vertical, 2)
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
                        appState.focusedPanel = panelSide
                        log.info("Size header tapped on side: \(panelSide)")
                        if sortKey == .size {
                            sortAscending.toggle()
                        } else {
                            sortKey = .size
                            sortAscending = true
                        }
                        appState.updateSorting(key: .size, ascending: sortAscending)
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
                        appState.focusedPanel = panelSide
                        log.info("Date header tapped on side: \(panelSide)")
                        if sortKey == .date {
                            sortAscending.toggle()
                        } else {
                            sortKey = .date
                            sortAscending = true
                        }
                        appState.updateSorting(key: .date, ascending: sortAscending)
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
                                .allowsHitTesting(false)
                        }
                        rowContent(file: file, isSel: isSel, index: index)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            selectedID = file.id
                            onSelect(file)
                        }
                    )
                    .overlay(isSel ? Rectangle().inset(by: 0.5).stroke(FilePanelStyle.selectedRowStroke, lineWidth: 1.0) : nil)
                    .shadow(color: isSel ? .black.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .stroke(FilePanelStyle.symlinkDirNameColor, lineWidth: FilePanelStyle.selectedBorderWidth)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
        )
    }
}
