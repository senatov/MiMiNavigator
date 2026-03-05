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
            ScrollViewReader { proxy in
                // ▲ Jump to First button
                scrollEdgeButton(
                    icon: "chevron.up.2",
                    help: "Jump to first file (Home)"
                ) {
                    keyboardNav.jumpToFirst()
                }

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
                // Scroll to anchor when keyboard nav changes it
                .onChange(of: scrollAnchorID) { _, newID in
                    guard let id = newID else { return }
                    withAnimation(.easeOut(duration: 0.05)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }

                // ▼ Jump to Last button
                scrollEdgeButton(
                    icon: "chevron.down.2",
                    help: "Jump to last file (End)"
                ) {
                    keyboardNav.jumpToLast()
                }
            }
        }
    }

    // MARK: - Scroll Edge Button (jump to first / last)
    private func scrollEdgeButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.accentColor.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 12)
            .background(Color(nsColor: .separatorColor).opacity(0.15))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
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
            .allowsHitTesting(false)
    }

}
