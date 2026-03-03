// VirtualizedFileList.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 03.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: High-performance virtualized file list for 10K+ items.
//   Only renders visible rows + buffer, uses fixed row height for O(1) scroll calculations.

import SwiftUI
import FileModelKit

// MARK: - Virtualized File List
/// Renders only visible rows for smooth scrolling with 10K+ files.
/// Uses fixed row height and scroll offset tracking for O(1) performance.
struct VirtualizedFileList: View {
    let rows: [(offset: Int, element: CustomFile)]
    @Binding var selectedID: CustomFile.ID?
    @Binding var scrollAnchorID: CustomFile.ID?
    let panelSide: PanelSide
    let layout: ColumnLayoutModel
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let handleFileAction: (FileAction, CustomFile) -> Void
    let handleDirectoryAction: (DirectoryAction, CustomFile) -> Void
    let handleMultiSelectionAction: (MultiSelectionAction) -> Void
    
    /// Number of extra rows to render above/below visible area
    private let bufferRows = 10
    
    /// Fixed row height from FilePanelStyle
    private let rowHeight: CGFloat = FilePanelStyle.rowHeight
    
    /// Threshold: use virtualization only for large lists
    private let virtualizationThreshold = 500
    
    @State private var visibleRect: CGRect = .zero
    
    var body: some View {
        if rows.count < virtualizationThreshold {
            // Small list — use standard LazyVStack (simpler, no overhead)
            standardList
        } else {
            // Large list — use virtualized rendering
            virtualizedList
        }
    }
    
    // MARK: - Standard List (< 500 items)
    private var standardList: some View {
        LazyVStack(spacing: 0) {
            ForEach(rows, id: \.element.id) { pair in
                row(for: pair.element, index: pair.offset)
                    .id(pair.element.id)
            }
        }
    }
    
    // MARK: - Virtualized List (500+ items)
    private var virtualizedList: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    // Total content height — allows correct scrollbar
                    Color.clear
                        .frame(height: CGFloat(rows.count) * rowHeight)
                        .overlay(alignment: .top) {
                            // Only render visible rows
                            visibleRowsStack
                                .offset(y: CGFloat(visibleRange.lowerBound) * rowHeight)
                        }
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: contentGeometry.frame(in: .named("scroll")).origin.y
                                )
                            }
                        )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    updateVisibleRect(scrollOffset: -offset, viewportHeight: geometry.size.height)
                }
                .onChange(of: scrollAnchorID) { _, newID in
                    if let id = newID {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scrollProxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Visible Rows Stack
    private var visibleRowsStack: some View {
        LazyVStack(spacing: 0) {
            ForEach(visibleRows, id: \.element.id) { pair in
                row(for: pair.element, index: pair.offset)
                    .frame(height: rowHeight)
                    .id(pair.element.id)
            }
        }
    }
    
    // MARK: - Calculate Visible Range
    private var visibleRange: Range<Int> {
        guard !rows.isEmpty else { return 0..<0 }
        
        let scrollOffset = max(0, -visibleRect.origin.y)
        let viewportHeight = max(visibleRect.height, 400)
        
        let firstVisible = max(0, Int(scrollOffset / rowHeight) - bufferRows)
        let lastVisible = min(rows.count, Int((scrollOffset + viewportHeight) / rowHeight) + bufferRows + 1)
        
        return firstVisible..<lastVisible
    }
    
    private var visibleRows: ArraySlice<(offset: Int, element: CustomFile)> {
        let range = visibleRange
        guard range.lowerBound < rows.count else { return [] }
        return rows[range]
    }
    
    private func updateVisibleRect(scrollOffset: CGFloat, viewportHeight: CGFloat) {
        visibleRect = CGRect(x: 0, y: -scrollOffset, width: 0, height: viewportHeight)
    }
    
    // MARK: - Row Builder
    @ViewBuilder
    private func row(for file: CustomFile, index: Int) -> some View {
        let isSelected = selectedID == file.id
        FileRow(
            index: index,
            file: file,
            isSelected: isSelected,
            panelSide: panelSide,
            layout: layout,
            onSelect: { tapped in onSelect(tapped) },
            onDoubleClick: { tapped in onDoubleClick(tapped) },
            onFileAction: { action, f in handleFileAction(action, f) },
            onDirectoryAction: { action, f in handleDirectoryAction(action, f) },
            onMultiSelectionAction: { action in handleMultiSelectionAction(action) }
        )
    }
}

// MARK: - Scroll Offset Preference Key
private struct ScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
