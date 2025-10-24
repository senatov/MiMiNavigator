    //
    //  FileRowView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 11.08.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import SwiftUI

    // MARK: -
struct FileTableView: View {
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onSelect: (CustomFile) -> Void
    @State private var sortKey: SortKeysEnum = .name
    @State private var sortAscending: Bool = true
        // Precomputed rows to ease type checker
    private var sortedRows: [(offset: Int, element: CustomFile)] {
        Array(sortedFiles.enumerated())
    }
        // Focus state helper
    private var isFocused: Bool { appState.focusedPanel == panelSide }
    
        // MARK: -
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                    // File Table header
                HStack(spacing: 8) {
                    getNameColSortableHeader()
                        // vertical separator
                    Divider().padding(.vertical, 2)
                    getSizeColSortableHeader()
                        // vertical separator
                    Divider().padding(.vertical, 2)
                    getDateSortableHeader()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.separator),
                    alignment: .bottom
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            FileTableRowsView(
                rows: sortedRows,
                selectedID: $selectedID,
                panelSide: panelSide,
                onSelect: onSelect,
                handleFileAction: handleFileAction,
                handleDirectoryAction: handleDirectoryAction
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? Color(nsColor: .systemBlue) : Color(Color.secondary).opacity(0.6),
                    lineWidth: isFocused ? max(FilePanelStyle.selectedBorderWidth, 0.7) : 0.5
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isFocused ? 0.10 : 0.05), lineWidth: 1)
        )
        .onTapGesture { appState.focusedPanel = panelSide }
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
    
        // MARK: - File actions handler
    func handleFileAction(_ action: FileAction, for file: CustomFile) {
        log.debug(#function + ": \(action)")
        switch action {
            case .cut:
                log.debug("File action: cut → \(file.pathStr)")
            case .copy:
                log.debug("File action: copy → \(file.pathStr)")
            case .pack:
                log.debug("File action: pack → \(file.pathStr)")
            case .viewLister:
                log.debug("File action: viewLister → \(file.pathStr)")
            case .createLink:
                log.debug("File action: createLink → \(file.pathStr)")
            case .delete:
                log.debug("File action: delete → \(file.pathStr)")
            case .rename:
                log.debug("File action: rename → \(file.pathStr)")
            case .properties:
                log.debug("File action: properties → \(file.pathStr)")
        }
    }
    
        // MARK: -
    private func getNameColSortableHeader() -> some View {
        return HStack(spacing: 4) {
            Text("Name").font(.subheadline)
            if sortKey == .name {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        .onTapGesture {
            log.debug("Name header tapped on side: \(panelSide)")
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
        return HStack(spacing: 4) {
            Text("Size").font(.subheadline)
            if sortKey == .size {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading).contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = panelSide
            log.debug("Size header tapped on side: \(panelSide)")
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
        return HStack(spacing: 4) {
            Text("Date").font(.subheadline)
            if sortKey == .date {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(width: FilePanelStyle.modifiedColumnWidth + 10, alignment: .leading).contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = panelSide
            log.debug("Date header tapped on side: \(panelSide)")
            if sortKey == .date {
                sortAscending.toggle()
            } else {
                sortKey = .date
                sortAscending = true
            }
            appState.updateSorting(key: .date, ascending: sortAscending)
        }
    }
    
        // MARK: - Directory actions handler
    func handleDirectoryAction(_ action: DirectoryAction, for file: CustomFile) {
        log.debug(#function + " for \(file.pathStr)")
        switch action {
            case .open:
                log.debug("Action: open → \(file.pathStr)")
            case .openInNewTab:
                log.debug("Action: openInNewTab → \(file.pathStr)")
            case .viewLister:
                log.debug("Action: viewLister → \(file.pathStr)")
            case .cut:
                log.debug("Action: cut → \(file.pathStr)")
            case .copy:
                log.debug("Action: copy → \(file.pathStr)")
            case .pack:
                log.debug("Action: pack → \(file.pathStr)")
            case .createLink:
                log.debug("Action: createLink → \(file.pathStr)")
            case .delete:
                log.debug("Action: delete → \(file.pathStr)")
            case .rename:
                log.debug("Action: rename → \(file.pathStr)")
            case .properties:
                log.debug("Action: properties → \(file.pathStr)")
        }
    }
    
        // MARK: - Sorting comparator extracted to help the type-checker
    func compare(_ a: CustomFile, _ b: CustomFile) -> Bool {
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
    var sortedFiles: [CustomFile] {
            // Always sort directories first, then apply selected column sort
        log.debug(#function + " for side <<\(panelSide)>>, sorting by \(sortKey), ascending: \(sortAscending)")
        let base: [CustomFile] = files
        let sorted = base.sorted(by: compare)
        return sorted
    }
}

