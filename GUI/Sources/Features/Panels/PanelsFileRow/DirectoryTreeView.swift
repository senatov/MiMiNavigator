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
    @State private var loadingSubtreePaths: Set<String> = []
    @State private var autoExpandedPath = ""

    private let maxAutoExpandRootCount = 60
    private let maxAutoExpandChildrenPerDirectory = 80
    private let maxAutoExpandedRows = 240

    private var visibleRows: [DirectoryTreeItem] {
        var rows: [DirectoryTreeItem] = []
        for file in files {
            appendVisibleRows(file, depth: 0, to: &rows)
        }
        return rows
    }

    private var currentPath: String {
        appState.path(for: panelSide)
    }

    private var filesSignature: Int {
        var hasher = Hasher()
        hasher.combine(currentPath)
        hasher.combine(files.count)
        for file in files {
            hasher.combine(file.id)
            hasher.combine(file.pathStr)
            hasher.combine(file.isDirectory)
            hasher.combine(file.modifiedDate?.timeIntervalSince1970 ?? 0)
        }
        return hasher.finalize()
    }

    private var treeAnimationID: String {
        expandedPaths.sorted().joined(separator: "|")
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
            .animation(.easeInOut(duration: 0.18), value: treeAnimationID)
        }
        .background(treeBackground)
        .clipped()
        .contextMenu { panelBackgroundMenu }
        .onAppear(perform: prepareTreeForCurrentPath)
        .onChange(of: filesSignature) { _, _ in prepareTreeForCurrentPath() }
        .onChange(of: appState.sortKey) { _, _ in resortLoadedChildren() }
        .onChange(of: appState.bSortAscending) { _, _ in resortLoadedChildren() }
    }

    // MARK: - Tree Rows
    private func treeRow(_ item: DirectoryTreeItem) -> some View {
        DirectoryTreeRow(
            file: item.file,
            depth: item.depth,
            isExpanded: isExpanded(item.file),
            isSelected: selectedID == item.file.id,
            isMarked: appState.isMarked(item.file, on: panelSide),
            isEmptyDirectory: isEmptyDirectory(item.file),
            isLoadingSubtree: loadingSubtreePaths.contains(item.file.pathStr),
            panelSide: panelSide,
            layout: layout,
            onToggle: { toggle(item.file) },
            onToggleSubtree: { toggleSubtree(item.file) },
            onSelect: { select(item.file) },
            onDoubleClick: { activate(item.file) },
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

    private func isEmptyDirectory(_ file: CustomFile) -> Bool {
        guard file.isDirectory || file.isSymbolicDirectory else { return false }
        if let children = childrenByPath[file.pathStr] {
            return children.isEmpty
        }
        if let childCount = file.childCount {
            return childCount == 0
        }
        return false
    }

    private func select(_ file: CustomFile) {
        selectedID = file.id
        onSelect(file)
    }

    private func activate(_ file: CustomFile) {
        if file.isDirectory || file.isSymbolicDirectory {
            return
        }
        onDoubleClick(file)
    }

    private func toggle(_ file: CustomFile) {
        guard file.isDirectory || file.isSymbolicDirectory else { return }
        if expandedPaths.contains(file.pathStr) {
            withAnimation(.easeInOut(duration: 0.18)) {
                let _ = expandedPaths.remove(file.pathStr)
            }
            return
        }
        if childrenByPath[file.pathStr] == nil {
            childrenByPath[file.pathStr] = loadChildren(for: file)
        }
        guard childrenByPath[file.pathStr]?.isEmpty == false else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            let _ = expandedPaths.insert(file.pathStr)
        }
    }

    private func toggleSubtree(_ file: CustomFile) {
        guard file.isDirectory || file.isSymbolicDirectory else { return }
        select(file)
        if expandedPaths.contains(file.pathStr) {
            collapseSubtree(file)
            return
        }
        guard !loadingSubtreePaths.contains(file.pathStr) else { return }
        loadingSubtreePaths.insert(file.pathStr)
        Task { @MainActor in
            await Task.yield()
            let rootPath = file.pathStr
            var expanded = Set<String>()
            var loadedChildren: [String: [CustomFile]] = [:]
            var visited = Set<String>()
            expandSubtree(file, expandedPaths: &expanded, childrenByPath: &loadedChildren, visitedPaths: &visited)
            for (path, children) in loadedChildren {
                childrenByPath[path] = children
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedPaths.formUnion(expanded)
            }
            loadingSubtreePaths.remove(rootPath)
        }
    }

    private func expandSubtree(
        _ file: CustomFile,
        expandedPaths: inout Set<String>,
        childrenByPath: inout [String: [CustomFile]],
        visitedPaths: inout Set<String>
    ) {
        let path = file.pathStr
        guard !visitedPaths.contains(path) else { return }
        visitedPaths.insert(path)
        let children = self.childrenByPath[path] ?? loadChildren(for: file)
        childrenByPath[path] = children
        guard !children.isEmpty else { return }
        expandedPaths.insert(path)
        for child in children where child.isDirectory || child.isSymbolicDirectory {
            expandSubtree(
                child,
                expandedPaths: &expandedPaths,
                childrenByPath: &childrenByPath,
                visitedPaths: &visitedPaths
            )
        }
    }

    private func collapseSubtree(_ file: CustomFile) {
        var pathsToCollapse: Set<String> = [file.pathStr]
        collectLoadedDescendantDirectoryPaths(from: file.pathStr, into: &pathsToCollapse)
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedPaths.subtract(pathsToCollapse)
        }
    }

    private func collectLoadedDescendantDirectoryPaths(from path: String, into result: inout Set<String>) {
        guard let children = childrenByPath[path] else { return }
        for child in children where child.isDirectory || child.isSymbolicDirectory {
            result.insert(child.pathStr)
            collectLoadedDescendantDirectoryPaths(from: child.pathStr, into: &result)
        }
    }

    private func loadChildren(for file: CustomFile) -> [CustomFile] {
        let url = file.urlValue
        let includeHidden = appState.showHiddenFilesSnapshot()
        let children = directoryContents(at: url, includeHidden: includeHidden)
        let files = children.compactMap { url -> CustomFile? in
            guard includeHidden || !url.lastPathComponent.hasPrefix(".") else { return nil }
            return CustomFile(path: url.path)
        }
        return appState.applySorting(files)
    }

    private func directoryContents(at url: URL, includeHidden: Bool) -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .contentModificationDateKey, .fileSizeKey],
                options: includeHidden ? [] : [.skipsHiddenFiles]
            )
        } catch {
            log.warning("[Tree] keyed directory read failed: \(url.path) error=\(error.localizedDescription)")
        }
        do {
            return try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: includeHidden ? [] : [.skipsHiddenFiles]
            )
        } catch {
            log.warning("[Tree] fallback directory read failed: \(url.path) error=\(error.localizedDescription)")
            return []
        }
    }

    private func drop(_ droppedFiles: [CustomFile], on file: CustomFile) -> Bool {
        guard file.isDirectory || file.isSymbolicDirectory else { return false }
        guard !droppedFiles.isEmpty else { return false }
        dragDropManager.prepareTransfer(files: droppedFiles, to: file.urlValue, from: dragDropManager.dragSourcePanelSide)
        return true
    }

    // MARK: - Auto Expand
    private func prepareTreeForCurrentPath() {
        if autoExpandedPath != currentPath {
            expandedPaths.removeAll()
            childrenByPath.removeAll()
            loadingSubtreePaths.removeAll()
            autoExpandedPath = currentPath
        }
        autoExpandInitialLevelsIfSmall()
    }

    private func autoExpandInitialLevelsIfSmall() {
        guard files.count <= maxAutoExpandRootCount else { return }
        var rowsBudget = maxAutoExpandedRows
        for file in files where rowsBudget > 0 {
            guard file.isDirectory || file.isSymbolicDirectory else { continue }
            let children = loadChildren(for: file)
            guard children.count <= maxAutoExpandChildrenPerDirectory else { continue }
            childrenByPath[file.pathStr] = children
            guard !children.isEmpty else { continue }
            expandedPaths.insert(file.pathStr)
            rowsBudget -= children.count
            for child in children where rowsBudget > 0 {
                guard child.isDirectory || child.isSymbolicDirectory else { continue }
                let grandchildren = loadChildren(for: child)
                guard grandchildren.count <= maxAutoExpandChildrenPerDirectory else { continue }
                childrenByPath[child.pathStr] = grandchildren
                guard !grandchildren.isEmpty else { continue }
                expandedPaths.insert(child.pathStr)
                rowsBudget -= grandchildren.count
            }
        }
    }

    private func resortLoadedChildren() {
        for key in Array(childrenByPath.keys) {
            if let children = childrenByPath[key] {
                childrenByPath[key] = appState.applySorting(children)
            }
        }
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
    let isEmptyDirectory: Bool
    let isLoadingSubtree: Bool
    let panelSide: FavPanelSide
    @Bindable var layout: ColumnLayoutModel
    let onToggle: () -> Void
    let onToggleSubtree: () -> Void
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    let onDrop: ([CustomFile]) -> Bool
    @State private var isDropTargeted = false

    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            nameCell
            ForEach(layout.fixedColumns.indices, id: \.self) { index in
                let spec = layout.fixedColumns[index]
                dividerSpacer
                fixedCell(spec)
            }
        }
        .frame(height: FilePanelStyle.rowHeight)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onDoubleClick)
        .simultaneousGesture(TapGesture(count: 1).onEnded { handleSingleClick() })
        .contextMenu { contextMenuContent }
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
            disclosureControl
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                .resizable()
                .frame(width: 16, height: 16)
                .opacity(isEmptyDirectory ? 0.55 : 1)
            Text(file.nameStr)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(nameForegroundStyle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(width: layout.nameWidth, alignment: .leading)
        .clipped()
    }

    @ViewBuilder
    private var disclosureControl: some View {
        if isLoadingSubtree {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.55)
                .frame(width: 12, height: 16)
        } else {
            Button(action: handleDisclosureClick) {
                Image(systemName: disclosureIcon)
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 12, height: 16)
                    .contentShape(Rectangle())
                    .opacity(disclosureOpacity)
            }
            .buttonStyle(.plain)
            .disabled(!isDirectory || isEmptyDirectory)
            .opacity(isDirectory ? 1 : 0)
        }
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

    private var dividerSpacer: some View {
        ZStack {
            Color.clear.frame(width: 14)
            Rectangle()
                .fill(ColorThemeStore.shared.activeTheme.dividerNormalColor)
                .frame(width: 1)
        }
        .frame(width: 14)
        .allowsHitTesting(false)
    }

    // MARK: - State
    private var isDirectory: Bool {
        file.isDirectory || file.isSymbolicDirectory
    }

    private var disclosureIcon: String {
        isExpanded ? "chevron.down" : "chevron.right"
    }

    private var disclosureOpacity: Double {
        guard isDirectory else { return 0 }
        return isEmptyDirectory ? 0.25 : 1
    }

    private var nameForegroundStyle: Color {
        if isEmptyDirectory {
            return Color(nsColor: .secondaryLabelColor).opacity(0.62)
        }
        return Color(nsColor: .labelColor)
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
            case .size: return file.displaySizeFormatted
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

    private func handleSingleClick() {
        onSelect()
        let modifiers = currentClickModifiers()
        appState.handleClickWithModifiers(on: file, modifiers: modifiers)
        if modifiers == .none, isDirectory {
            onToggle()
        }
    }

    private func handleDisclosureClick() {
        guard isDirectory, !isEmptyDirectory else { return }
        onToggleSubtree()
    }

    private func currentClickModifiers() -> ClickModifiers {
        guard let flags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) else {
            return .none
        }
        if flags.contains(.command) { return .command }
        if flags.contains(.shift) { return .shift }
        return .none
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if appState.markedCount(for: panelSide) > 0 {
            MultiSelectionContextMenu(
                markedCount: appState.markedCount(for: panelSide),
                panelSide: panelSide,
                isOptionHeld: optionHeld
            ) { action in
                CntMenuCoord.shared.handleMultiSelectionAction(action, panel: panelSide, appState: appState)
            }
        } else if file.isDirectory || file.isSymbolicDirectory {
            DirectoryContextMenu(file: file, panelSide: panelSide, isOptionHeld: optionHeld) { action in
                CntMenuCoord.shared.handleDirectoryAction(action, for: file, panel: panelSide, appState: appState)
            }
        } else {
            FileContextMenu(file: file, panelSide: panelSide, isOptionHeld: optionHeld) { action in
                CntMenuCoord.shared.handleFileAction(action, for: file, panel: panelSide, appState: appState)
            }
        }
    }
}
