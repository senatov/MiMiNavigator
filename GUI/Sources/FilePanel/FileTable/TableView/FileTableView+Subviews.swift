// FileTableView+Subviews.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: View components for FileTableView

import SwiftUI

// MARK: - Subviews
extension FileTableView {
    
    var mainScrollView: some View {
        VStack(spacing: 0) {
            // Sticky header - outside ScrollView
            TableHeaderView(
                panelSide: panelSide,
                sortKey: $sortKey,
                sortAscending: $sortAscending,
                sizeColumnWidth: $sizeColumnWidth,
                dateColumnWidth: $dateColumnWidth,
                typeColumnWidth: $typeColumnWidth,
                permissionsColumnWidth: $permissionsColumnWidth,
                ownerColumnWidth: $ownerColumnWidth,
                onSave: saveColumnWidths
            )
            
            // Scrollable content with background context menu
            ZStack {
                // Background layer with context menu for empty area
                Color.clear
                    .contentShape(Rectangle())
                    .contextMenu { panelBackgroundMenu }
                
                // File rows on top
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        StableKeyView(cachedSortedFiles.count) {
                            FileTableRowsView(
                                rows: sortedRows,
                                selectedID: $selectedID,
                                panelSide: panelSide,
                                sizeColumnWidth: sizeColumnWidth,
                                dateColumnWidth: dateColumnWidth,
                                typeColumnWidth: typeColumnWidth,
                                permissionsColumnWidth: permissionsColumnWidth,
                                ownerColumnWidth: ownerColumnWidth,
                                onSelect: onSelect,
                                onDoubleClick: onDoubleClick,
                                handleFileAction: handleFileAction,
                                handleDirectoryAction: handleDirectoryAction
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Empty space at bottom to allow right-click on empty area
                        Color.clear
                            .frame(height: max(100, 300))
                            .contentShape(Rectangle())
                            .contextMenu { panelBackgroundMenu }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: 40)
                }
            }
            .background(keyboardShortcutsLayer)
        }
    }
    
    @ViewBuilder
    var panelBackgroundMenu: some View {
        let currentPath = appState.pathURL(for: panelSide) ?? URL(fileURLWithPath: "/")
        PanelBackgroundContextMenu(
            panelSide: panelSide,
            currentPath: currentPath,
            onAction: handlePanelBackgroundAction
        )
    }
    
    var panelBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
                isPanelDropTargeted
                    ? Color.accentColor.opacity(0.8)
                    : (isFocused ? Color.accentColor.opacity(0.3) : Color.clear),
                lineWidth: isPanelDropTargeted ? 2 : 1
            )
            .allowsHitTesting(false)
    }
    
    var keyboardShortcutsLayer: some View {
        TableKeyboardShortcutsView(
            isFocused: isFocused,
            onPageUp: keyboardNav.jumpToFirst,
            onPageDown: keyboardNav.jumpToLast,
            onHome: keyboardNav.jumpToFirst,
            onEnd: keyboardNav.jumpToLast
        )
    }
}
