// FileTableView+Subviews.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: View components for FileTableView — scroll area, jump buttons, panel border

import AppKit
import SwiftUI

// MARK: - Subviews
extension FileTableView {

    /// Width of the macOS native scrollbar track (system default ~15pt)
    private static let scrollbarWidth: CGFloat = 15

    private var onePixel: CGFloat {
        1.0 / (NSScreen.main?.backingScaleFactor ?? 2.0)
    }

    var mainScrollView: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(spacing: 0) {
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
                        } header: {
                            TableHeaderView(
                                panelSide: panelSide,
                                layout: layout
                            )
                        }
                    }
                    .scrollTargetLayout()

                    // 1px breathing room inside scroll content so the bottom selection border isn't clipped.
                    Color.clear
                    .frame(height: onePixel)
                }
            }
            .background(scrollBackgroundLayer)
            .scrollClipDisabled()
            // Jump-to-edge buttons (aligned with scrollbar)
            .overlay(alignment: .trailing) {
                jumpButtonsOverlay
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 4)
            }
            .contextMenu { panelBackgroundMenu }
        }
    }

    // MARK: - Scroll Background (Zebra)

    private var scrollBackgroundLayer: some View {
        ZStack {
            scrollZebraBackground

            // Hit layer for empty area clicks. Does NOT receive events from subviews (rows).
            Color.clear
            .contentShape(Rectangle())
            .gesture(emptyAreaTapGesture, including: .gesture)
        }
    }

    private var scrollZebraBackground: some View {
        ZebraBackgroundFill(
            startIndex: 0,
            isActivePanel: appState.focusedPanel == panelSide,
            rowHeight: FilePanelStyle.rowHeight
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var emptyAreaTapGesture: some Gesture {
        ExclusiveGesture(
            TapGesture(count: 2),
            TapGesture(count: 1)
        )
        .onEnded { gesture in
            switch gesture {
            case .first:
                // Double-click on empty area → clear marks (like Esc)
                appState.unmarkAll(on: panelSide)
                selectedID = nil
            case .second:
                // Single-click on empty area → exit multi-selection and deselect
                appState.unmarkAll(on: panelSide)
                selectedID = nil
            }
        }
    }

    // MARK: - Jump Buttons

    @ViewBuilder
    private var jumpButtonsOverlay: some View {
        if sortedRows.count > 50 {
            VStack(spacing: 0) {
                scrollEdgeButton(icon: "chevron.up.2") {
                    NotificationCenter.default.post(
                        name: .jumpToFirst,
                        object: panelSide
                    )
                }
                .help("Jump to top (Home)")

                Spacer()

                scrollEdgeButton(icon: "chevron.down.2") {
                    NotificationCenter.default.post(
                        name: .jumpToLast,
                        object: panelSide
                    )
                }
                .help("Jump to bottom (End)")
            }
            .frame(width: Self.scrollbarWidth)
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