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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        FileTableRowsView(
                            rows: sortedRows,
                            selectedID: $selectedID,
                            panelSide: panelSide,
                            layout: layout,
                            onSelect: onSelect,
                            onDoubleClick: onDoubleClick,
                            handleFileAction: handleFileAction,
                            handleDirectoryAction: handleDirectoryAction,
                            handleMultiSelectionAction: handleMultiSelectionAction
                        )

                        // Empty space — clickable for background context menu
                        Color.clear
                            .opacity(0.01)
                            .frame(minHeight: 300)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .contextMenu { panelBackgroundMenu }
                            .onTapGesture { selectedID = nil }

                    } header: {
                        TableHeaderView(
                            panelSide: panelSide,
                            layout: layout
                        )
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
        let hasMarkedDirs = appState.markedCustomFiles(for: panelSide).contains { $0.isDirectory }
        PanelBackgroundContextMenu(
            panelSide: panelSide,
            currentPath: currentPath,
            canGoBack: appState.selectionsHistory.canGoBack,
            canGoForward: appState.selectionsHistory.canGoForward,
            hasMarkedDirectories: hasMarkedDirs,
            onAction: handlePanelBackgroundAction
        )
    }

    var panelBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
                isPanelDropTargeted
                    ? Color.accentColor.opacity(0.8)
                    : Color.clear,
                lineWidth: isPanelDropTargeted ? 2 : 1
            )
            .shadow(
                color: isFocused ? Color.accentColor.opacity(0.28) : Color.clear,
                radius: isFocused ? 8 : 0,
                x: 0, y: 0
            )
            .allowsHitTesting(false)
    }

    var keyboardShortcutsLayer: some View {
        TableKeyboardShortcutsView(
            isFocused: isFocused,
            onPageUp: keyboardNav.pageUp,
            onPageDown: keyboardNav.pageDown,
            onHome: keyboardNav.jumpToFirst,
            onEnd: keyboardNav.jumpToLast
        )
    }
}
