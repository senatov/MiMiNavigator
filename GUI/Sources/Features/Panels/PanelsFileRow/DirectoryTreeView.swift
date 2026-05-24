// DirectoryTreeView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Lazy expandable directory tree panel mode.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Directory Tree View
struct DirectoryTreeView: View {
    @Environment(AppState.self) private var appState
    @Environment(DragDropManager.self) private var dragDropManager
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: FavPanelSide
    @Bindable var layout: ColumnLayoutModel
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    @State private var expandedPaths: Set<String> = []
    @State private var childrenByPath: [String: [CustomFile]] = [:]

    private var visibleRows: [DirectoryTreeItem] {
        var rows: [DirectoryTreeItem] = []
        for file in files {
            appendVisibleRows(file, depth: 0, to: &rows)
        }
        return rows
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(visibleRows) { item in
                    treeRow(item)
                }
            }
            .padding(.vertical, 1)
        }
        .background(treeBackground)
        .contextMenu { panelBackgroundMenu }
    }

    // MARK: - Tree Rows
    private func treeRow(_ item: DirectoryTreeItem) -> some View {
        DirectoryTreeRow(
            file: item.file,
            depth: item.depth,
            isExpanded: isExpanded(item.file),
            isSelected: selectedID == item.file.id,
            isMarked: appState.isMarked(item.file, on: panelSide),
            panelSide: panelSide,
            layout: layout,
            onToggle: { toggle(item.file) },
            onSelect: { select(item.file) },
            onDoubleClick: { onDoubleClick(item.file) },
            onDrop: { droppedFiles in drop(droppedFiles, on: item.file) }
        )
    }

    // MARK: - Row Actions
    private func appendVisibleRows(_ file: CustomFile, depth: Int, to rows: inout [DirectoryTreeItem]) {
        rows.append(DirectoryTreeItem(file: file, depth: depth))
        guard isExpanded(file), let children = childrenByPath[file.pathStr] else { return }
        for child in children {
            appendVisibleRows(child, depth: depth + 1, to: &rows)
        }
    }

    private func isExpanded(_ file: CustomFile) -> Bool {
        expandedPaths.contains(file.pathStr)
    }

    private func select(_ file: CustomFile) {
        selectedID = file.id
        onSelect(file)
    }

    private func toggle(_ file: CustomFile) {
        guard file.isDirectory || file.isSymbolicDirectory else { return }
        if expandedPaths.contains(file.pathStr) {
            expandedPaths.remove(file.pathStr)
            return
        }
        expandedPaths.insert(file.pathStr)
        if childrenByPath[file.pathStr] == nil {
            loadChildren(for: file)
        }
    }

    private func loadChildren(for file: CustomFile) {
        let url = file.urlValue
        let includeHidden = appState.showHiddenFilesSnapshot()
        let children = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .contentModificationDateKey, .fileSizeKey],
            options: includeHidden ? [] : [.skipsHiddenFiles]
        )) ?? []
        let files = children.compactMap { url -> CustomFile? in
            guard includeHidden || !url.lastPathComponent.hasPrefix(".") else { return nil }
            return CustomFile(path: url.path)
        }
        childrenByPath[file.pathStr] = appState.applySorting(files)
    }

    private func drop(_ droppedFiles: [CustomFile], on file: CustomFile) -> Bool {
        guard file.isDirectory || file.isSymbolicDirectory else { return false }
        guard !droppedFiles.isEmpty else { return false }
        dragDropManager.prepareTransfer(files: droppedFiles, to: file.urlValue, from: dragDropManager.dragSourcePanelSide)
        return true
    }

    // MARK: - Background
    private var treeBackground: some View {
        ZebraBackgroundFill(
            startIndex: 0,
            isActivePanel: appState.focusedPanel == panelSide,
            rowHeight: FilePanelStyle.rowHeight
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var panelBackgroundMenu: some View {
        let currentPath = appState.pathURL(for: panelSide) ?? URL(fileURLWithPath: "/")
        PanelBackgroundContextMenu(
            panelSide: panelSide,
            currentPath: currentPath,
            canGoBack: appState.selectionsHistory.canGoBack,
            canGoForward: appState.selectionsHistory.canGoForward,
            hasMarkedDirectories: false,
            isOptionHeld: NSEvent.modifierFlags.contains(.option),
            onAction: { action in CntMenuCoord.shared.handlePanelBackgroundAction(action, for: panelSide, appState: appState) }
        )
    }
}

// MARK: - Directory Tree Item
private struct DirectoryTreeItem: Identifiable {
    let file: CustomFile
    let depth: Int
    var id: String { "\(depth):\(file.id)" }
}

// MARK: - Directory Tree Row
private struct DirectoryTreeRow: View {
    @Environment(AppState.self) private var appState
    @Environment(DragDropManager.self) private var dragDropManager
    let file: CustomFile
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let isMarked: Bool
    let panelSide: FavPanelSide
    @Bindable var layout: ColumnLayoutModel
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    let onDrop: ([CustomFile]) -> Bool
    @State private var isDropTargeted = false

    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            nameCell
            ForEach(layout.fixedColumns, id: \.id) { spec in
                fixedCell(spec)
            }
        }
        .frame(height: FilePanelStyle.rowHeight)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onDoubleClick)
        .simultaneousGesture(TapGesture(count: 1).onEnded { onSelect() })
        .modifier(dropModifier)
        .onDrag {
            dragDropManager.startDrag(files: [file], from: panelSide, appState: appState)
            return NSItemProvider(object: file.urlValue as NSURL)
        }
    }

    // MARK: - Cells
    private var nameCell: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(depth) * 16)
            Button(action: onToggle) {
                Image(systemName: disclosureIcon)
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .opacity(isDirectory ? 1 : 0)
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                .resizable()
                .frame(width: 16, height: 16)
            Text(file.nameStr)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(width: layout.nameWidth, alignment: .leading)
        .clipped()
    }

    private func fixedCell(_ spec: ColumnSpec) -> some View {
        Text(text(for: spec.id))
            .font(spec.id == .permissions ? .system(size: 11, design: .monospaced) : .system(size: 12))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(width: spec.width, alignment: spec.id.alignment)
            .clipped()
    }

    // MARK: - State
    private var isDirectory: Bool {
        file.isDirectory || file.isSymbolicDirectory
    }

    private var disclosureIcon: String {
        isExpanded ? "chevron.down" : "chevron.right"
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                Color.accentColor.opacity(0.22)
            } else if isMarked {
                Color.accentColor.opacity(0.12)
            } else if isDropTargeted {
                Color.accentColor.opacity(0.14)
            } else {
                Color.clear
            }
        }
    }

    private var dropModifier: DropTargetModifier {
        DropTargetModifier(
            isValidTarget: isDirectory,
            isDropTargeted: $isDropTargeted,
            onDrop: onDrop,
            onTargetChange: { isDropTargeted = $0 }
        )
    }

    private func text(for col: ColumnID) -> String {
        switch col {
            case .name: return file.nameStr
            case .dateModified: return file.modifiedDateFormatted
            case .size: return file.fileSizeFormatted
            case .kind: return file.kindFormatted
            case .permissions: return file.permissionsFormatted
            case .owner: return file.ownerFormatted
            case .childCount: return file.childCountFormatted
            case .dateCreated: return file.creationDateFormatted
            case .dateLastOpened: return file.lastOpenedFormatted
            case .dateAdded: return file.dateAddedFormatted
            case .group: return file.groupNameFormatted
        }
    }
}
