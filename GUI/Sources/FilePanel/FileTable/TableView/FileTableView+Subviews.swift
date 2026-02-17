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
                onSave: saveColumnWidths,
                autoFitSize: { autoFitSize() },
                autoFitDate: { autoFitDate() },
                autoFitPermissions: { autoFitPermissions() },
                autoFitOwner: { autoFitOwner() },
                autoFitType: { autoFitType() }
            )
            
            // Scrollable content — context menu on entire scroll area + empty space filler
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
                            handleDirectoryAction: handleDirectoryAction,
                            handleMultiSelectionAction: handleMultiSelectionAction
                        )
                    }
                    
                    // Empty space at bottom — clickable for background context menu
                    Color(nsColor: .controlBackgroundColor)
                        .opacity(0.01)
                        .frame(minHeight: 300)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .contextMenu { panelBackgroundMenu }
                        .onTapGesture {
                            // Deselect on click in empty area
                            selectedID = nil
                        }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 40)
            }
            .contextMenu { panelBackgroundMenu }
            .background(keyboardShortcutsLayer)
        }
    }
    
    @ViewBuilder
    var panelBackgroundMenu: some View {
        let currentPath = appState.pathURL(for: panelSide) ?? URL(fileURLWithPath: "/")
        PanelBackgroundContextMenu(
            panelSide: panelSide,
            currentPath: currentPath,
            canGoBack: appState.selectionsHistory.canGoBack,
            canGoForward: appState.selectionsHistory.canGoForward,
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
