// FilePanelView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

// MARK: - File panel view for one side (left or right)
struct FilePanelView: View {
    @Environment(AppState.self) var appState
    @State private var colorStore = ColorThemeStore.shared
    @State private var viewModel: FilePanelViewModel
    @State private var viewModeStore = PanelViewModeStore.shared
    let containerWidth: CGFloat
    @Binding var leftPanelWidth: CGFloat
    let onPanelTap: (FavPanelSide) -> Void

    private var panelURL: URL {
        switch viewModel.panelSide {
            case .left:
                return appState.leftURL
            case .right:
                return appState.rightURL
        }
    }

    private var isRemotePanel: Bool {
        AppState.isRemotePath(panelURL)
    }

    private var currentMode: PanelViewMode {
        viewModeStore.mode(for: viewModel.panelSide)
    }

    private var rawFiles: [CustomFile] {
        viewModel.sortedFiles
    }

    private var files: [CustomFile] {
        prependParentEntry(to: rawFiles, currentPath: panelURL.path)
    }

    private var fileContentKey: String {
        makeFileContentKey(files: files, path: panelURL.path)
    }

    private var firstNonParentFile: CustomFile? {
        files.first(where: { !$0.isParentEntry })
    }

    private var remoteConnectionManager: RemoteConnectionManager {
        RemoteConnectionManager.shared
    }

    // MARK: - Init
    init(
        selectedSide: FavPanelSide,
        containerWidth: CGFloat,
        leftPanelWidth: Binding<CGFloat>,
        fetchFiles: @escaping @Sendable @concurrent (FavPanelSide) async -> Void,
        appState: AppState,
        onPanelTap: @escaping (FavPanelSide) -> Void = { _ in }
    ) {
        self._leftPanelWidth = leftPanelWidth
        self.containerWidth = containerWidth
        self._viewModel = State(
            initialValue: FilePanelViewModel(
                panelSide: selectedSide,
                appState: appState,
                fetchFiles: fetchFiles
            )
        )
        self.onPanelTap = onPanelTap
    }

    // MARK: - View
    var body: some View {
        VStack {
            TabBarView(panelSide: viewModel.panelSide)
            breadcrumbSection
            contentSection
            SelectionStatusBar(panelSide: viewModel.panelSide)
        }
        .padding(.horizontal, DesignTokens.grid)
        .padding(.vertical, DesignTokens.grid - 2)
        .background(panelBackground)
        .frame(width: calculatedWidth)
        .animation(nil, value: leftPanelWidth)
        .transaction { tx in
            tx.disablesAnimations = true
            tx.animation = nil
        }
        .background(DesignTokens.panelBg)
        .overlay(focusRingOverlay)
        .overlay { navigationOverlay }
        .controlSize(.regular)
        .contentShape(Rectangle())
        .panelFocus(panelSide: viewModel.panelSide) {
            appState.showFavTreePopup = false
        }
    }

    // MARK: - View Sections
    private var breadcrumbSection: some View {
        StableKeyView(panelURL.path) {
            PanelBreadcrumbSection(
                panelSide: viewModel.panelSide,
                currentPath: panelURL,
                onPathChange: { newValue in
                    viewModel.handlePathChange(to: newValue)
                }
            )
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if currentMode == .thumbnail {
            thumbnailSection
        } else {
            fileTableSection
        }
    }

    private var thumbnailSection: some View {
        ThumbnailGridView(
            files: files,
            selectedID: selectedIDBinding,
            panelSide: viewModel.panelSide,
            cellSize: viewModeStore.thumbSize(for: viewModel.panelSide),
            onSelect: { file in viewModel.select(file) },
            onDoubleClick: handleDoubleClick
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileTableSection: some View {
        StableKeyView(fileContentKey) {
            PanelFileTableSection(
                files: files,
                selectedID: selectedIDBinding,
                panelSide: viewModel.panelSide,
                onPanelTap: onPanelTap,
                onSelect: { file in
                    viewModel.select(file)
                },
                onDoubleClick: handleDoubleClick
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var navigationOverlay: some View {
        if appState.navigatingPanel == viewModel.panelSide {
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(1.2)
                    .controlSize(.regular)
                Text("Loading…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: appState.navigatingPanel)
        }
    }

    // MARK: - Binding to selected file ID
    private var selectedIDBinding: Binding<CustomFile.ID?> {
        Binding<CustomFile.ID?>(
            get: {
                selectedFile?.id
            },
            set: { newValue in
                if newValue == nil {
                    clearSelectedFile()
                    appState.selectedDir.selectedFSEntity = nil
                    appState.showFavTreePopup = false
                }
            }
        )
    }

    private var selectedFile: CustomFile? {
        switch viewModel.panelSide {
            case .left:
                return appState.selectedLeftFile
            case .right:
                return appState.selectedRightFile
        }
    }

    private func setSelectedFile(_ file: CustomFile?) {
        switch viewModel.panelSide {
            case .left:
                appState.selectedLeftFile = file
            case .right:
                appState.selectedRightFile = file
        }
    }

    private func clearSelectedFile() {
        setSelectedFile(nil)
    }

    // MARK: - View mode picker bar — removed (list/grid moved to toolbar, slider to status bar)

    // MARK: - Panel background with focus indicator
    private var panelBackground: some View {
        let focused = appState.focusedPanel == viewModel.panelSide
        return ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .fill(focused ? DesignTokens.warmWhite : DesignTokens.card)
            // Border — soft but visible, stronger on focused panel
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .stroke(
                    focused
                        ? colorStore.activeTheme.panelBorderActive
                        : colorStore.activeTheme.panelBorderInactive,
                    lineWidth: colorStore.activeTheme.panelBorderWidth
                )
        }
        .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.15), value: focused)
        .drawingGroup()
    }

    // MARK: - Focus ring overlay — removed per design decision
    @ViewBuilder
    private var focusRingOverlay: some View {
        EmptyView()
    }

    // MARK: - Calculated panel width
    private var calculatedWidth: CGFloat? {
        viewModel.panelSide == .left
            ? (leftPanelWidth > 0 ? leftPanelWidth : containerWidth / 2)
            : nil
    }

    private func canEnterRemoteItem(_ file: CustomFile) -> Bool {
        file.isDirectory || file.isParentEntry
    }

    // MARK: - Handle double click (archive-aware)
    private func logRemoteActivation(_ file: CustomFile) {
        log.debug("[FilePanelView] remote activate name=\(file.nameStr)")
        log.debug("[FilePanelView] remote activate path=\(file.pathStr)")
        log.debug("[FilePanelView] remote activate isDir=\(file.isDirectory) isParent=\(file.isParentEntry)")
    }

    private func handleDoubleClick(_ file: CustomFile) {
        let _ = log.debug(#function)
        if isRemotePanel {
            logRemoteActivation(file)

            guard canEnterRemoteItem(file) else {
                log.debug("[FilePanelView] remote activate ignored")
                return
            }
            enterRemoteDirectory(file)
            return
        }
        // Delegate to shared activation logic (same as Enter key)
        appState.activateItem(file, on: viewModel.panelSide)
    }

    // MARK: - Enter remote directory
    private func enterRemoteDirectory(_ file: CustomFile) {
        guard let connection = remoteConnectionManager.activeConnection else {
            log.error("[FilePanelView] enterRemoteDirectory failed: no active remote connection")
            return
        }
        let newPath = file.urlValue.path
        log.debug("[FilePanelView] remote entry name=\(file.nameStr)")
        log.debug("[FilePanelView] remote entry isParent=\(file.isParentEntry)")
        log.info("[FilePanelView] enterRemoteDirectory: \(newPath)")
        Task { @MainActor in
            // Update connection's current path and re-list
            do {
                let items = try await remoteConnectionManager.listDirectory(newPath)
                let remoteFiles = items.map { CustomFile(remoteItem: $0) }
                let sortedFiles = appState.applySorting(remoteFiles)
                let origin = AppState.remoteOrigin(from: connection.provider.mountPath)
                let sanitized = newPath.hasPrefix("/") ? newPath : "/\(newPath)"
                let cleanURLString = sanitized == "/" ? origin + "/" : origin + sanitized
                guard let cleanURL = URL(string: cleanURLString) else {
                    log.error("[FilePanelView] invalid remote URL: \(cleanURLString)")
                    return
                }
                appState.updatePath(cleanURL, for: viewModel.panelSide)
                applyRemoteFiles(sortedFiles)
            } catch {
                log.error("[FilePanelView] remote listing failed: \(error.localizedDescription)")
            }
        }
    }

    private func applyRemoteFiles(_ files: [CustomFile]) {
        let _ = log.debug(#function + ": \(files.count)")
        let firstNonParent = files.first(where: { !$0.isParentEntry })
        switch viewModel.panelSide {
            case .left:
                appState.displayedLeftFiles = files
            case .right:
                appState.displayedRightFiles = files
        }
        setSelectedFile(firstNonParent)
    }

    // MARK: - Enter directory

    private func refreshLocalDirectory(_ url: URL) async {
        let _ = log.debug(#function + ": \(url.path)")
        appState.updatePath(url, for: viewModel.panelSide)
        switch viewModel.panelSide {
            case .left:
                await appState.scanner.setLeftDirectory(pathStr: url.path)
                await appState.scanner.refreshFiles(currSide: .left)
                await appState.refreshLeftFiles()
            case .right:
                await appState.scanner.setRightDirectory(pathStr: url.path)
                await appState.scanner.refreshFiles(currSide: .right)
                await appState.refreshRightFiles()
        }
    }

    private func enterDirectory(_ file: CustomFile) {
        let _ = log.debug(#function)
        let newURL = file.urlValue.resolvingSymlinksInPath()
        let newPath = newURL.path

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: newPath, isDirectory: &isDir), isDir.boolValue else {
            showCannotOpenAlert(file)
            return
        }

        Task { @MainActor in
            await refreshLocalDirectory(newURL)
        }
    }

    // MARK: - Open file with default app
    private func openFile(_ file: CustomFile) {
        let _ = log.debug(#function + ": \(file.nameStr)")
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(file.urlValue, configuration: configuration) { app, error in
            if let error = error {
                log.error("Failed to open file: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Show alert for broken symlink
    private func showCannotOpenAlert(_ file: CustomFile) {
        let alert = NSAlert()
        alert.messageText = "Cannot Open Directory"
        alert.informativeText =
            "The directory \"\(file.nameStr)\" cannot be opened. It may be a broken symlink or you may not have permission."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Prepend ".." parent directory entry
    private func prependParentEntry(to files: [CustomFile], currentPath: String?) -> [CustomFile] {
        guard let path = currentPath, path != "/" else {
            return files
        }

        let parentEntry = ParentDirectoryEntry.make(for: path)
        return [parentEntry] + files
    }

    // MARK: - Generate content-aware key for file table refresh
    private func makeFileContentKey(files: [CustomFile], path: String?) -> String {
        var components: [String] = []
        components.append(path ?? "nil")
        components.append(String(files.count))

        // Include first few file names to detect content changes.
        for file in files.prefix(3) {
            components.append(file.nameStr)
        }
        // Include last file name
        if let last = files.last {
            components.append(last.nameStr)
        }

        return components.joined(separator: "|")
    }
}
