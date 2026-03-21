// FileTableView+Subviews.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: View components for FileTableView — scroll area, jump buttons, panel border

import SwiftUI

// MARK: - Subviews
extension FileTableView {

    /// Width of the macOS native scrollbar track (system default ~15pt)
    private static let scrollbarWidth: CGFloat = 15
    var mainScrollView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
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

                            // Zebra-striped empty space below file rows
                            ZebraBackgroundFill(
                                startIndex: sortedRows.count,
                                isActivePanel: appState.focusedPanel == panelSide,
                                rowHeight: FilePanelStyle.rowHeight
                            )
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .contextMenu { panelBackgroundMenu }
                            // Double-click on empty area → clear marks (like Esc)
                            .onTapGesture(count: 2) {
                                appState.unmarkAll(on: panelSide)
                            }
                            // Single-click → just deselect file (keep marks)
                            .onTapGesture {
                                selectedID = nil
                            }

                        } header: {
                            TableHeaderView(
                                panelSide: panelSide,
                                layout: layout
                            )
                        }
                    }
                    .scrollTargetLayout()
                }
                // MARK: - Jump-to-edge buttons (top & bottom, aligned with scrollbar)
                .overlay(alignment: .trailing) {
                    if sortedRows.count > 50 {
                        VStack(spacing: 0) {
                            // ▲ Jump to first
                            scrollEdgeButton(icon: "chevron.up.2") {
                                NotificationCenter.default.post(
                                    name: .jumpToFirst,
                                    object: panelSide
                                )
                            }
                            .help("Jump to top (Home)")
                           
                            Spacer()

                            // ▼ Jump to last
                            scrollEdgeButton(icon: "chevron.down.2") {
                                NotificationCenter.default.post(
                                    name: .jumpToLast,
                                    object: panelSide
                                )
                            }
                            .help("Jump to bottom (End)")
                        }
                        .frame(width: Self.scrollbarWidth)
                        .padding(.trailing, 0)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: 4)
                }
                .contextMenu { panelBackgroundMenu }
            }
        }
    }

    // MARK: - Scroll Edge Button (3D square, matches scrollbar width)
    /// Compact square button sitting at the edge of the scrollbar track.
    /// Uses a subtle 3D gradient + shadow for a tactile, embossed look.
    private func scrollEdgeButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.secondary)
                .frame(width: Self.scrollbarWidth, height: Self.scrollbarWidth)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
                .shadow(color: .white.opacity(0.5), radius: 0.5, x: 0, y: -0.5)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
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
