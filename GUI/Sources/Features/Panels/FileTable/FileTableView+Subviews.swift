    // FileTableView+Subviews.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 04.02.2026.
    // Copyright © 2024-2026 Senatov. All rights reserved.
    // Description: View components for FileTableView — scroll area, jump buttons, panel border

    import FileModelKit
    import FileProvider
    import Foundation
    import SwiftUI
    import MiMiNavigator

    // MARK: - Scroll Detection PreferenceKey
    private struct ScrollHeightKey: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    // MARK: - Subviews
    extension FileTableView {

        var mainScrollView: some View {
            ScrollAwareContainer(
                rows: sortedRows,
                selectedID: $selectedID,
                panelSide: panelSide,
                layout: layout,
                appState: appState,
                onSelect: onSelect,
                onDoubleClick: onDoubleClick,
                handleFileAction: handleFileAction,
                handleDirectoryAction: handleDirectoryAction,
                handleMultiSelectionAction: handleMultiSelectionAction,
                panelBackgroundMenu: panelBackgroundMenu,
                jumpButtonsColumn: jumpButtonsColumn
            )
        }

        // MARK: - Jump Buttons Column (above & below scroller area)

        private var jumpButtonsColumn: some View {
            VStack(spacing: 2) {
                // ▲ Jump to top
                glassSquareButton(icon: "chevron.up") {
                    NotificationCenter.default.post(name: .jumpToFirst, object: panelSide)
                }
                .help("Jump to top (Home)")

                Spacer()

                // ▼ Jump to bottom
                glassSquareButton(icon: "chevron.down") {
                    NotificationCenter.default.post(name: .jumpToLast, object: panelSide)
                }
                .help("Jump to bottom (End)")
            }
            .frame(width: 18)
            .padding(.vertical, 2)
            .padding(.trailing, 2)
        }

        // MARK: - Glass Square Button (Control Center style)

        private func glassSquareButton(icon: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .compositingGroup()
                            .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 0.5)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.9), .white.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .buttonStyle(.plain)
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
                    isPanelDropTargeted ? Color.accentColor.opacity(0.8) : Color.clear,
                    lineWidth: isPanelDropTargeted ? 2 : 1
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - ScrollAwareContainer

    private struct ScrollAwareContainer: View {

        // MARK: - Inputs

        let rows: [CustomFile]
        @Binding var selectedID: CustomFile.ID?
        let panelSide: PanelSide
        let layout: FileTableLayout
        let appState: AppState

        let onSelect: (CustomFile) -> Void
        let onDoubleClick: (CustomFile) -> Void
        let handleFileAction: (FileAction, CustomFile) -> Void
        let handleDirectoryAction: (DirectoryAction, CustomFile) -> Void
        let handleMultiSelectionAction: (MultiSelectionAction) -> Void

        let panelBackgroundMenu: AnyView
        let jumpButtonsColumn: AnyView

        // MARK: - State

        @State private var contentHeight: CGFloat = 0

        // MARK: - Body

        var body: some View {
            GeometryReader { geo in
                let needsScroll = contentHeight > geo.size.height

                HStack(spacing: 0) {

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {

                            Section {
                                FileTableRowsView(
                                    rows: rows,
                                    selectedID: $selectedID,
                                    panelSide: panelSide,
                                    layout: layout,
                                    onSelect: onSelect,
                                    onDoubleClick: onDoubleClick,
                                    handleFileAction: { file in
                                        handleFileAction(.default, file)
                                    },
                                    handleDirectoryAction: { dir in
                                        handleDirectoryAction(.default, dir)
                                    },
                                    handleMultiSelectionAction: { action in
                                        handleMultiSelectionAction(action)
                                    }
                                )

                                ZebraBackgroundFill(
                                    startIndex: rows.count,
                                    isActivePanel: appState.focusedPanel == panelSide,
                                    rowHeight: FilePanelStyle.rowHeight
                                )
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    appState.unmarkAll(on: panelSide)
                                }
                                .onTapGesture {
                                    selectedID = nil
                                }

                            } header: {
                                TableHeaderView(panelSide: panelSide, layout: layout)
                            }
                        }
                        .scrollTargetLayout()
                        .background(
                            GeometryReader {
                                Color.clear
                                    .preference(key: ScrollHeightKey.self, value: $0.size.height)
                            }
                        )
                    }
                    .scrollIndicators(.automatic)
                    .scrollBounceBehavior(.basedOnSize)
                    .onPreferenceChange(ScrollHeightKey.self) { value in
                        contentHeight = value
                    }

                    if needsScroll {
                        jumpButtonsColumn
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: needsScroll)
                    }
                }
            }
        }
    }
