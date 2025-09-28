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
    private enum SortKey { case name, size, date }
    @State private var sortKey: SortKey = .name
    @State private var sortAscending: Bool = true
    // Focus state helper
    private var isFocused: Bool { appState.focusedPanel == panelSide }

    // MARK: -
    var body: some View {
        log.info(
            #function + " side: \(panelSide) with \(files.count) files, selectedID: \(String(describing: selectedID)))")
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // File Table header
                HStack(spacing: 8) {
                    getNameColSortableHeader()
                    // vertical separator
                    Rectangle().frame(width: 1).foregroundColor(Color.secondary.opacity(0.25)).padding(.vertical, 2)
                    getSizeColSortableHeader()
                    // vertical separator
                    Rectangle().frame(width: 1).foregroundColor(Color.secondary.opacity(0.25)).padding(.vertical, 2)
                    getDateSortableHeader()
                }
                .padding(.vertical, 4).padding(.horizontal, 6).background(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 7).frame(height: 0.6).foregroundColor(.secondary.opacity(0.55)),
                    alignment: .bottom
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            LazyVStack(spacing: 0) {
                ForEach(Array(sortedFiles.enumerated()), id: \.element.id) { index, file in
                    let isSel = (selectedID == file.id)
                    drawFileLineInTheTable(index, isSel, file)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isFocused ? Color(nsColor: .systemBlue) : FilePanelStyle.blueSymlinkDirNameColor.opacity(0.35),
                    lineWidth: isFocused ? max(FilePanelStyle.selectedBorderWidth, 2) : 1
                )
                .shadow(
                    color: isFocused ? .black.opacity(0.25) : .black.opacity(0.1),
                    radius: isFocused ? 4 : 2,
                    x: 1,
                    y: 1
                )
        )
        .onTapGesture { appState.focusedPanel = panelSide }.animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    // MARK: -
    private func getNameColSortableHeader() -> some View {
        log.info(#function)
        return HStack(spacing: 4) {
            Text("Name").font(.subheadline)
            if sortKey == .name {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
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
    }

    // MARK: -
    private func getSizeColSortableHeader() -> some View {
        // log.info(#function + " for side: \(panelSide), sortKey: \(sortKey), ascending: \(sortAscending)")
        return HStack(spacing: 4) {
            Text("Size").font(.subheadline)
            if sortKey == .size {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading).contentShape(Rectangle())
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
    }

    // MARK: -
    private func getDateSortableHeader() -> some View {
        // log.info(#function + " for side: \(panelSide), sortKey: \(sortKey), ascending: \(sortAscending)")
        return HStack(spacing: 4) {
            Text("Date").font(.subheadline)
            if sortKey == .date {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(width: FilePanelStyle.modifiedColumnWidth + 10, alignment: .leading).contentShape(Rectangle())
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

    // MARK: -
    @ViewBuilder private func highlightedSquare(_ isSel: Bool) -> some View {
        if isSel {
            Rectangle().inset(by: 0.2).stroke(FilePanelStyle.blueSymlinkDirNameColor.gradient, lineWidth: 1.0)
        } else {
            EmptyView()
        }
    }

    // MARK: -
    private func drawFileLineInTheTable(_ index: Int, _ isSelected: Bool, _ file: CustomFile) -> some View {
        return ZStack(alignment: .leading) {
            // Zebra background stripes (Finder-like)
            (index.isMultiple(of: 2) ? Color.white : Color.gray.opacity(0.1)).allowsHitTesting(false)
            if isSelected {
                Rectangle().fill(FilePanelStyle.yellowSelRowFill).allowsHitTesting(false)
            }
            rowContent(file: file)
        }
        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        .help(file.id)
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    selectedID = file.id
                    onSelect(file)
                }
        )
        .overlay(highlightedSquare(isSelected))
        .shadow(color: isSelected ? .black.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }

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
    @ViewBuilder private func rowContent(file: CustomFile) -> some View {
        HStack(alignment: .center, spacing: 8) {
            // Name column (expands)
            FileRowView(file: file, panelSide: panelSide)
                .frame(maxWidth: .infinity, alignment: .leading)
            // vertical separator
            Rectangle().frame(width: 1).foregroundColor(Color.secondary.opacity(0.15)).padding(.vertical, 2)
            // Size column
            Text(file.fileObjTypEnum)
                .foregroundColor(
                    Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1))
                )
                .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading)
            // vertical separator
            Rectangle().frame(width: 1).foregroundColor(Color.secondary.opacity(0.15)).padding(.vertical, 2)
            // Date column
            Text(file.modifiedDateFormatted)
                .foregroundColor(
                    Color(#colorLiteral(red: 0.3098039329, green: 0.01568627544, blue: 0.1294117719, alpha: 1))
                )
                .frame(width: FilePanelStyle.modifiedColumnWidth + 10, alignment: .leading)
        }
        .padding(.vertical, 2).padding(.horizontal, 6)
    }
}
