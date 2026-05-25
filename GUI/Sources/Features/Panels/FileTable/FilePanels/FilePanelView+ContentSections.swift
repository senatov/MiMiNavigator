// FilePanelView+ContentSections.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Display mode sections for FilePanelView.

import FileModelKit
import SwiftUI

// MARK: - File Panel Content Sections
extension FilePanelView {
    @ViewBuilder
    var contentSection: some View {
        if currentMode == .list {
            fileTableSection
        } else if currentMode == .thumbnail {
            thumbnailSection
        } else {
            treeSection
        }
    }

    var tableHeaderSection: some View {
        TableHeaderView(
            panelSide: viewModel.panelSide,
            layout: columnLayout,
            isFocused: appState.focusedPanel == viewModel.panelSide
        )
    }

    var thumbnailSection: some View {
        VStack(spacing: 0) {
            tableHeaderSection
            ThumbnailGridView(
                files: files,
                selectedID: selectedIDBinding,
                panelSide: viewModel.panelSide,
                cellSize: viewModeStore.thumbSize(for: viewModel.panelSide),
                onSelect: { file in viewModel.select(file) },
                onDoubleClick: handleDoubleClick
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(panelDropTargetModifier)
        .onAppear(perform: registerNonListKeyboardCallbacks)
    }

    var treeSection: some View {
        VStack(spacing: 0) {
            ParentNavigationStripPanel(
                panelSide: viewModel.panelSide,
                isHighlighted: false,
                onSelect: { file in
                    selectedIDBinding.wrappedValue = nil
                    viewModel.select(file)
                },
                onActivate: { file in
                    handleDoubleClick(file)
                }
            )
            tableHeaderSection
            DirectoryTreeView(
                files: files,
                selectedID: selectedIDBinding,
                panelSide: viewModel.panelSide,
                layout: columnLayout,
                onSelect: { file in viewModel.select(file) },
                onDoubleClick: handleDoubleClick
            )
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .modifier(panelDropTargetModifier)
        .onAppear(perform: registerNonListKeyboardCallbacks)
    }

    var fileTableSection: some View {
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
        .modifier(panelDropTargetModifier)
    }

    var panelDropTargetModifier: DropTargetModifier {
        DropTargetModifier(
            isValidTarget: true,
            isDropTargeted: .constant(false),
            onDrop: handlePanelDrop,
            onTargetChange: handlePanelDropTargetChange
        )
    }

    func handlePanelDrop(_ droppedFiles: [CustomFile]) -> Bool {
        guard !droppedFiles.isEmpty else { return false }
        let destinationURL = appState.url(for: viewModel.panelSide)
        dragDropManager.prepareTransfer(
            files: droppedFiles,
            to: destinationURL,
            from: dragDropManager.dragSourcePanelSide
        )
        log.info("[FilePanelView] panel drop: \(droppedFiles.count) file(s) → \(destinationURL.lastPathComponent)")
        return true
    }

    func handlePanelDropTargetChange(_ targeted: Bool) {
        guard targeted else { return }
        dragDropManager.setDropTarget(appState.url(for: viewModel.panelSide))
    }

    // MARK: - Non-list Keyboard Navigation
    func registerNonListKeyboardCallbacks() {
        guard currentMode != .list else { return }
        appState.navigationCallbacks[viewModel.panelSide] = PanelNavigationCallbacks(
            moveUp: { [self] in selectRelative(-1) },
            moveDown: { [self] in selectRelative(1) },
            pageUp: { [self] in selectRelative(-20) },
            pageDown: { [self] in selectRelative(20) },
            jumpToFirst: { [self] in selectAtIndex(0) },
            jumpToLast: { [self] in selectAtIndex(nonParentFiles.count - 1) }
        )
        log.debug("[FilePanelView] registered non-list keyboard callbacks panel=\(viewModel.panelSide) mode=\(currentMode.rawValue)")
    }

    var nonParentFiles: [CustomFile] {
        files.filter { !$0.isParentEntry && $0.nameStr != ".." }
    }

    func selectRelative(_ delta: Int) {
        let items = nonParentFiles
        guard !items.isEmpty else { return }
        let currentIndex = selectedFileIndex(in: items)
        selectAtIndex(max(0, min(items.count - 1, currentIndex + delta)))
    }

    func selectAtIndex(_ index: Int) {
        let items = nonParentFiles
        guard index >= 0, index < items.count else { return }
        let file = items[index]
        viewModel.select(file)
        appState.setSelectedIndex(index + 1, for: viewModel.panelSide)
    }

    func selectedFileIndex(in items: [CustomFile]) -> Int {
        guard let selected = appState.panel(viewModel.panelSide).selectedFile,
              let index = items.firstIndex(where: { $0.id == selected.id })
        else { return 0 }
        return index
    }
}
