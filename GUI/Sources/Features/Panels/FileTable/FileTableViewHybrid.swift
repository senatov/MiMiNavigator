// FileTableViewHybrid.swift
// MiMiNavigator
//
// Created by Claude on 03.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Hybrid table view that uses NSTableView for performance
//              while keeping SwiftUI header and integration with existing architecture.

import FileModelKit
import SwiftUI

// MARK: - Hybrid File Table View
/// Combines SwiftUI header with high-performance NSTableView body.
/// Preserves all existing functionality: sorting, selection, keyboard nav, drag-drop.
struct FileTableViewHybrid: View {
    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager

    let panelSide: FavPanelSide
    let files: [CustomFile]
    let filesVersion: Int  // Version number for efficient change detection
    @Binding var selectedID: CustomFile.ID?
    let layout: ColumnLayoutModel
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void

    @State private var colorStore = ColorThemeStore.shared
    @State private var isPanelDropTargeted: Bool = false

    private var isFocused: Bool { appState.focusedPanel == panelSide }

    /// Background color for entire panel
    private var panelBackgroundColor: Color {
        log.debug(#function + ": isFocused: \(isFocused)")
        return isFocused ? colorStore.activeTheme.warmWhite : Color(nsColor: .controlBackgroundColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            // SwiftUI header (existing, working)
            TableHeaderView(panelSide: panelSide, layout: layout, isFocused: isFocused)

            // Separator line
            Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)

            // NSTableView body with glass jump buttons overlay
            ZStack(alignment: .trailing) {
                NSFileTableView(
                    panelSide: panelSide,
                    files: files,
                    filesVersion: filesVersion,
                    sortKey: appState.sortKey,
                    sortAscending: appState.bSortAscending,
                    selectedID: $selectedID,
                    layout: layout,
                    colorStore: colorStore,
                    isFocused: isFocused,
                    onSelect: handleSelect,
                    onDoubleClick: onDoubleClick
                )

                // Glass-style jump buttons (show when > 30 files)
                if files.count > 30 {
                    glassJumpButtons
                    .padding(.trailing, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(panelBorder)
        .contentShape(Rectangle())
        .focusable(true)
        .focusEffectDisabled()
        // Keyboard navigation
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .up: moveSelection(by: -1)
            case .down: moveSelection(by: 1)
            default: break
            }
        }
        .onKeyPress(.pageUp) {
            guard isFocused else { return .ignored }
            moveSelection(by: -20)
            return .handled
        }
        .onKeyPress(.pageDown) {
            guard isFocused else { return .ignored }
            moveSelection(by: 20)
            return .handled
        }
        .onKeyPress(.home) {
            guard isFocused else { return .ignored }
            selectFirst()
            return .handled
        }
        .onKeyPress(.end) {
            guard isFocused else { return .ignored }
            selectLast()
            return .handled
        }
        .onKeyPress(.escape) {
            guard isFocused else { return .ignored }
            if appState.markedCount(for: panelSide) > 0 {
                appState.unmarkAll()
            }
            return .handled
        }
        // Update AppState index when selection changes
        .onChange(of: selectedID) { _, newID in
            if let id = newID, let idx = files.firstIndex(where: { $0.id == id }) {
                appState.setSelectedIndex(idx + 1, for: panelSide)
            } else {
                appState.setSelectedIndex(0, for: panelSide)
            }
        }
    }

    // MARK: - Panel Border
    private var panelBorder: some View {
        log.debug(#function + ": Re-rendering panel border")
        return RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(
            isPanelDropTargeted ? Color.accentColor.opacity(0.8) : Color.clear,
            lineWidth: isPanelDropTargeted ? 2 : 1
        )
        .allowsHitTesting(false)
    }

    // MARK: - Keyboard Navigation

    private func moveSelection(by delta: Int) {
        guard !files.isEmpty else { return }
        log.debug(#function + ": Moving selection by \(delta)")
        let currentIdx: Int
        if let id = selectedID, let idx = files.firstIndex(where: { $0.id == id }) {
            currentIdx = idx
        } else {
            currentIdx = delta > 0 ? -1 : files.count
        }

        let newIdx = max(0, min(files.count - 1, currentIdx + delta))
        let file = files[newIdx]
        selectedID = file.id
        onSelect(file)
    }

    private func selectFirst() {
        guard let first = files.first else { return }
        selectedID = first.id
        onSelect(first)
    }

    private func selectLast() {
        guard let last = files.last else { return }
        selectedID = last.id
        onSelect(last)
    }

    // MARK: - Selection Handler

    private func handleSelect(_ file: CustomFile) {
        log.debug(#function + ": Selecting file with ID \(file.id)")
        onSelect(file)
    }

    // MARK: - Glass Jump Buttons

    /// Frosted glass style buttons for jumping to start/end of list
    private var glassJumpButtons: some View {
        VStack(spacing: 0) {
            // ▲ Jump to first
            glassButton(icon: "chevron.up.2") {
                selectFirst()
            }
            .help("Jump to top (Home)")

            Spacer()

            // ▼ Jump to last
            glassButton(icon: "chevron.down.2") {
                selectLast()
            }
            .help("Jump to bottom (End)")
        }
    }

    /// Individual glass button — Control Center style (white pill, frosted glass)
    private func glassButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .background {
                Capsule()
                .fill(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 0.5)
            }
            .overlay {
                Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .white.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
            }
        }
        .buttonStyle(.plain)
    }

}
