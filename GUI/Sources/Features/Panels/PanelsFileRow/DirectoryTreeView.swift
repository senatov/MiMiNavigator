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
    @State private var autoFitTask: Task<Void, Never>?
    @State private var autoExpandedPath = ""

    private enum TreeMetrics {
        static let depthIndent: CGFloat = 16
        static let disclosureReserve: CGFloat = 16
    }

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
        .onChange(of: appState.sortKey) { _, _ in resortLoadedChildrenAndFit() }
        .onChange(of: appState.bSortAscending) { _, _ in resortLoadedChildrenAndFit() }
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
            isExpandableDirectory: isExpandableDirectory(item.file),
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

    private func isExpandableDirectory(_ file: CustomFile) -> Bool {
        if file.isDirectory || file.isSymbolicDirectory { return true }
        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: file.urlValue.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return true
        }
        if let values = try? file.urlValue.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true {
            return true
        }
        return false
    }

    private func isEmptyDirectory(_ file: CustomFile) -> Bool {
        guard isExpandableDirectory(file) else { return false }
        if let children = childrenByPath[file.pathStr] {
            return children.isEmpty
        }
        if let childCount = file.childCount {
            if childCount == 0, needsLiveDirectoryProbe(file) {
                return false
            }
            return childCount == 0
        }
        return false
    }

    private func needsLiveDirectoryProbe(_ file: CustomFile) -> Bool {
        if file.isSymbolicDirectory { return true }
        let path = file.urlValue.path
        return path.contains("/Library/CloudStorage/")
            || path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Google Drive").path)
            || path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("OneDrive").path)
            || path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("ProtonDrive").path)
    }

    private func select(_ file: CustomFile) {
        selectedID = file.id
        onSelect(file)
    }

    private func activate(_ file: CustomFile) {
        if isExpandableDirectory(file) {
            return
        }
        onDoubleClick(file)
    }

    private func toggle(_ file: CustomFile) {
        guard isExpandableDirectory(file) else { return }
        if expandedPaths.contains(file.pathStr) {
            withAnimation(.easeInOut(duration: 0.18)) {
                let _ = expandedPaths.remove(file.pathStr)
            }
            scheduleTreeAutoFit(reason: "collapse")
            return
        }
        if childrenByPath[file.pathStr] == nil {
            childrenByPath[file.pathStr] = loadChildren(for: file)
        }
        guard childrenByPath[file.pathStr]?.isEmpty == false else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            let _ = expandedPaths.insert(file.pathStr)
        }
        scheduleTreeAutoFit(reason: "expand")
    }

    private func toggleSubtree(_ file: CustomFile) {
        guard isExpandableDirectory(file) else { return }
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
            scheduleTreeAutoFit(reason: "expand-subtree")
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
        for child in children where isExpandableDirectory(child) {
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
        scheduleTreeAutoFit(reason: "collapse-subtree")
    }

    private func collectLoadedDescendantDirectoryPaths(from path: String, into result: inout Set<String>) {
        guard let children = childrenByPath[path] else { return }
        for child in children where isExpandableDirectory(child) {
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
        guard isExpandableDirectory(file) else { return false }
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
        scheduleTreeAutoFit(reason: "prepare")
    }

    private func autoExpandInitialLevelsIfSmall() {
        guard files.count <= maxAutoExpandRootCount else { return }
        var rowsBudget = maxAutoExpandedRows
        for file in files where rowsBudget > 0 {
            guard isExpandableDirectory(file) else { continue }
            let children = loadChildren(for: file)
            guard children.count <= maxAutoExpandChildrenPerDirectory else { continue }
            childrenByPath[file.pathStr] = children
            guard !children.isEmpty else { continue }
            expandedPaths.insert(file.pathStr)
            rowsBudget -= children.count
            for child in children where rowsBudget > 0 {
                guard isExpandableDirectory(child) else { continue }
                let grandchildren = loadChildren(for: child)
                guard grandchildren.count <= maxAutoExpandChildrenPerDirectory else { continue }
                childrenByPath[child.pathStr] = grandchildren
                guard !grandchildren.isEmpty else { continue }
                expandedPaths.insert(child.pathStr)
                rowsBudget -= grandchildren.count
            }
        }
    }

    private func resortLoadedChildrenAndFit() {
        for key in Array(childrenByPath.keys) {
            if let children = childrenByPath[key] {
                childrenByPath[key] = appState.applySorting(children)
            }
        }
        scheduleTreeAutoFit(reason: "sort")
    }

    private func scheduleTreeAutoFit(reason: String) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        autoFitTask?.cancel()
        autoFitTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            if Task.isCancelled { return }
            let rows = visibleRows
            guard !rows.isEmpty else { return }
            let files = rows.map(\.file)
            let extras = rows.map { nameExtraWidth(forDepth: $0.depth) }
            log.debug("[AutoFit] tree fit panel=\(panelSide) reason=\(reason) rows=\(rows.count)")
            ColumnAutoFitter.autoFitAll(layout: layout, files: files, nameExtraWidths: extras)
        }
    }

    private func nameExtraWidth(forDepth depth: Int) -> CGFloat {
        CGFloat(depth) * TreeMetrics.depthIndent + TreeMetrics.disclosureReserve
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
