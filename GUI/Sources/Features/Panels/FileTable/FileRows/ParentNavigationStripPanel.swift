// ParentNavigationStripPanel.swift
// MiMiNavigator
//
// Created by Claude on 22.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Fixed panel above file table showing ".." parent-navigation strip.
//   Lives outside ScrollView — not part of file rows, not selectable via context menu,
//   not participating in keyboard row navigation. Activates parent dir on click/dblclick.
//   Visual appearance identical to the old in-table ParentEntryStripView.

import FileModelKit
import SwiftUI

// MARK: - ParentNavigationStripPanel

/// Fixed panel placed above the file table ScrollView.
/// Shows parent directory path with pebble button; click navigates up.
/// Not a file row — has no context menu, no row selection, no keyboard nav index.
struct ParentNavigationStripPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(DragDropManager.self) private var dragDropManager

    let panelSide: FavPanelSide
    let isHighlighted: Bool
    let onSelect: (CustomFile) -> Void
    let onActivate: (CustomFile) -> Void

    private enum Metrics {
        static let height: CGFloat = 25
        static let utilitySpacing: CGFloat = 3
        static let utilityWidth: CGFloat = 66

        static var reservedTrailingWidth: CGFloat {
            utilityWidth + utilitySpacing
        }
    }
    private var currentPath: String {
        appState.path(for: panelSide)
    }

    private var remoteURL: URL? {
        guard let url = URL(string: currentPath), AppState.isRemotePath(url) else { return nil }
        return url
    }

    private var remotePath: String {
        guard let remoteURL else { return "/" }
        return remoteURL.path.isEmpty ? "/" : remoteURL.path
    }

    private var shouldShow: Bool {
        if remoteURL != nil {
            return remotePath != "/"
        }
        return currentPath != "/"
    }

    private var parentPath: String {
        if remoteURL != nil {
            let parent = (remotePath as NSString).deletingLastPathComponent
            return parent.isEmpty ? "/" : parent
        }
        return (currentPath as NSString).deletingLastPathComponent
    }

    private var parentFile: CustomFile {
        CustomFile(name: "..", path: parentPath, children: nil, isParentEntry: true)
    }


    private var parentURL: URL {
        parentFile.urlValue
    }

    private var displayParentPath: String {
        let state = appState.archiveState(for: panelSide)
        guard state.isInsideArchive,
              let archiveURL = state.archiveURL,
              let tempDir = state.archiveTempDir
        else {
            return parentURL.path == "/" ? "/Root" : parentURL.path
        }
        if state.isAtArchiveRoot(currentPath: currentPath) {
            let archiveParent = archiveURL.deletingLastPathComponent()
            return archiveParent.path == "/" ? "/Root" : archiveParent.path
        }
        let current = URL(fileURLWithPath: currentPath).standardizedFileURL.path
        let root = tempDir.standardizedFileURL.path
        let relative = current.hasPrefix(root + "/") ? String(current.dropFirst(root.count + 1)) : ""
        let relativeParent = (relative as NSString).deletingLastPathComponent
        if relativeParent.isEmpty {
            return archiveURL.lastPathComponent
        }
        return "\(archiveURL.lastPathComponent)  ›  \(relativeParent)"
    }

    private var transferDestinationURL: URL {
        let state = appState.archiveState(for: panelSide)
        if state.isInsideArchive,
           state.isAtArchiveRoot(currentPath: currentPath),
           let archiveURL = state.archiveURL {
            return archiveURL.deletingLastPathComponent()
        }
        return parentURL
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            parentNavigationArea
                .padding(.trailing, Metrics.reservedTrailingWidth)
                .zIndex(1)
            utilityButtons
                .zIndex(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.height)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Color(nsColor: .separatorColor)
                .frame(height: 1)
        }
        .zIndex(10)
    }

    @ViewBuilder
    private var parentNavigationArea: some View {
        if shouldShow {
            ParentEntryStripView(
                file: parentFile,
                isSelected: isHighlighted,
                parentURL: parentURL,
                displayParentPath: displayParentPath,
                onSelect: onSelect,
                onActivate: activateParent,
                onDrop: handleDrop,
                onDropTargetChange: handleDropTargetChange,
                isExternalDropContact: dragDropManager.dropDestinationOverride == transferDestinationURL
            )
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.height)
        }
    }

    private var utilityButtons: some View {
        BreadCrumbToolBar(selectedSide: panelSide, content: .utilities)
            .frame(
                width: Metrics.utilityWidth,
                height: Metrics.height,
                alignment: .leading
            )
    }

    // MARK: - Activation
    private func activateParent(_ file: CustomFile) {
        if remoteURL != nil {
            Task { @MainActor in
                await appState.navigateToParent(on: panelSide)
            }
            return
        }
        onActivate(file)
    }
    // MARK: - Drop Handling
    private func handleDrop(_ files: [CustomFile]) -> Bool {
        guard !files.isEmpty else { return false }
        let destination = transferDestinationURL
        dragDropManager.prepareTransfer(
            files: files,
            to: destination,
            from: dragDropManager.dragSourcePanelSide
        )
        log.info("[ToParent] \(files.count) file(s) → \(destination.path)")
        return true
    }
    private func handleDropTargetChange(_ targeted: Bool) {
        let destination = transferDestinationURL
        if targeted {
            dragDropManager.setDropTarget(destination)
            dragDropManager.setDropDestinationOverride(destination)
        } else if dragDropManager.dropDestinationOverride == destination {
            dragDropManager.setDropDestinationOverride(nil)
        }
    }
}
