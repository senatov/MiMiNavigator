// FileTableView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.08.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Main file table view with sortable, resizable columns
//
// Architecture:
//   - FileTableView+Subviews.swift   → View components (scroll, border, shortcuts)
//   - FileTableView+Actions.swift    → Action handlers
//   - FileTableView+State.swift      → State management (columns, sorting)

import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Table View
/// Displays file list with sortable columns, keyboard navigation, and drag-drop support
struct FileTableView: View {
    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager
    
    let panelSide: PanelSide
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    
    // MARK: - Local State
    @State var sortKey: SortKeysEnum = .name
    @State var sortAscending: Bool = true
    @State var cachedSortedFiles: [CustomFile] = []
    @State var scrollProxy: ScrollViewProxy?
    @State var isPanelDropTargeted: Bool = false

    // MARK: - Column Layout (replaces individual CGFloat @State for each column)
    @State var layout: ColumnLayoutModel

    // MARK: - Init
    init(panelSide: PanelSide, files: [CustomFile], selectedID: Binding<CustomFile.ID?>,
         onSelect: @escaping (CustomFile) -> Void, onDoubleClick: @escaping (CustomFile) -> Void) {
        self.panelSide = panelSide
        self.files = files
        self._selectedID = selectedID
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
        self._layout = State(initialValue: ColumnLayoutModel(panelSide: panelSide))
    }
    
    // MARK: - Computed Properties
    var isFocused: Bool { appState.focusedPanel == panelSide }

    var sorter: TableFileSorter { TableFileSorter(sortKey: sortKey, ascending: sortAscending) }
    
    var keyboardNav: TableKeyboardNavigation {
        TableKeyboardNavigation(
            files: cachedSortedFiles,
            selectedID: $selectedID,
            onSelect: onSelect,
            scrollProxy: scrollProxy
        )
    }
    
    var dropHandler: TableDropHandler {
        TableDropHandler(panelSide: panelSide, appState: appState, dragDropManager: dragDropManager)
    }
    
    var sortedRows: [(offset: Int, element: CustomFile)] {
        Array(cachedSortedFiles.enumerated())
    }
    
    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            mainScrollView
                .onAppear {
                    log.debug("\(#function) FileTableView onAppear panel=\(panelSide) files.count=\(files.count)")
                    scrollProxy = proxy
                    recomputeSortedCache()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(panelBorder)
        .contentShape(Rectangle())
        .animation(nil, value: isFocused)
        .animation(nil, value: selectedID)
        .focusable(true)
        .focusEffectDisabled()
        .onChange(of: files) { recomputeSortedCache() }
        .onChange(of: sortKey) { recomputeSortedCache() }
        .onChange(of: sortAscending) { recomputeSortedCache() }
        // No auto-scroll on selection change — user controls scroll position
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .up: keyboardNav.moveUp()
            case .down: keyboardNav.moveDown()
            default: break
            }
        }
        .dropDestination(for: URL.self) { droppedURLs, _ in
            // Prefer internal drag (preserves multi-selection), fallback to URL decode
            let droppedFiles = DropTargetModifier.safeResolveURLs(droppedURLs, dragDropManager: dragDropManager)
            guard !droppedFiles.isEmpty else { return false }
            return dropHandler.handlePanelDrop(droppedFiles)
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPanelDropTargeted = targeted
            }
            dropHandler.updateDropTarget(targeted: targeted)
        }
    }
}
