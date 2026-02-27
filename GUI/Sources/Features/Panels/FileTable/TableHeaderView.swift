// TableHeaderView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Sortable, resizable column headers. Right-click → context menu to toggle columns.
//
// Interaction model:
//   - Click sort arrow icon → toggle sort direction
//   - Double-click column title area → auto-fit column width to content
//   - Drag divider between columns → resize
//
// Layout logic:
//   [Name flexible] | divider | [col2 fixed] | divider | [col3 fixed] | ...

import FileModelKit
import SwiftUI

// MARK: - Table Header View

struct TableHeaderView: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide
    @Bindable var layout: ColumnLayoutModel

    private var sortKey: SortKeysEnum { appState.sortKey }
    private var sortAscending: Bool { appState.bSortAscending }

    var body: some View {
        let fixedCols = layout.visibleColumns.filter { $0.id != .name }
        return HStack(alignment: .center, spacing: 0) {
            nameHeader
            ForEach(fixedCols.indices, id: \.self) { i in
                let spec = fixedCols[i]
                ResizableDivider(
                    width: Binding(
                        get: { spec.width },
                        set: { layout.setWidth($0, for: spec.id) }
                    ),
                    min: TableColumnDefaults.minWidth,
                    max: TableColumnDefaults.maxWidth,
                    onEnd: { layout.saveWidths() }
                )
                fixedColumnHeader(for: spec)
            }
        }
        .frame(height: 22)
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(TableHeaderStyle.backgroundColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TableHeaderStyle.separatorColor)
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
        .contextMenu { columnToggleMenu }
    }

    // MARK: - Name Column (flexible)

    private var nameHeader: some View {
        SortableHeader(
            title: ColumnID.name.title,
            icon: ColumnID.name.icon,
            sortKey: ColumnID.name.sortKey,
            currentKey: sortKey,
            ascending: sortAscending,
            onSort: { toggleSort(.name) },
            onAutoFit: nil
        )
        .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    // MARK: - Fixed Column Header

    private func fixedColumnHeader(for spec: ColumnSpec) -> some View {
        SortableHeader(
            title: spec.id.title,
            icon: spec.id.icon,
            sortKey: spec.id.sortKey,
            currentKey: sortKey,
            ascending: sortAscending,
            onSort: { toggleSort(spec.id) },
            onAutoFit: {
                autoFitColumn(spec.id)
            }
        )
        .frame(width: spec.width, alignment: spec.id.alignment)
        .padding(.horizontal, TableColumnDefaults.cellPadding)
    }

    // MARK: - Context Menu (right-click on header)

    @ViewBuilder
    private var columnToggleMenu: some View {
        ForEach(layout.columns) { spec in
            let col = spec.id
            if !col.isRequired {
                Button {
                    layout.toggle(col)
                } label: {
                    Label(col.title, systemImage: spec.isVisible ? "checkmark" : "")
                }
            }
        }
        Divider()
        Button("Restore Defaults") { restoreDefaults() }
    }

    // MARK: - Sort Toggle

    private func toggleSort(_ col: ColumnID) {
        guard let key = col.sortKey else { return }
        appState.focusedPanel = panelSide
        if sortKey == key {
            appState.bSortAscending.toggle()
        } else {
            appState.sortKey = key
            appState.bSortAscending = true
        }
        log.debug("[Sort] toggleSort panel=\(panelSide) key=\(appState.sortKey) asc=\(appState.bSortAscending)")
        appState.updateSorting()
    }

    // MARK: - Auto-fit Column Width

    private func autoFitColumn(_ col: ColumnID) {
        let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        guard !files.isEmpty else { return }

        let texts: [String]
        let font: NSFont
        switch col {
        case .size:
            texts = files.map { $0.fileSizeFormatted }
            font = .systemFont(ofSize: 12)
        case .dateModified:
            texts = files.map { $0.modifiedDateFormatted }
            font = .systemFont(ofSize: 12)
        case .kind:
            texts = files.map { $0.kindFormatted }
            font = .systemFont(ofSize: 12)
        case .permissions:
            texts = files.map { $0.permissionsFormatted }
            font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        case .owner:
            texts = files.map { $0.ownerFormatted }
            font = .systemFont(ofSize: 12)
        case .childCount:
            texts = files.map { $0.childCountFormatted }
            font = .systemFont(ofSize: 12)
        case .name:
            return
        }

        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var maxW: CGFloat = 0
        for text in texts {
            let w = (text as NSString).size(withAttributes: attrs).width
            if w > maxW { maxW = w }
        }
        let optimal = ceil(maxW + 16)
        let clamped = Swift.min(Swift.max(optimal, TableColumnDefaults.minWidth), TableColumnDefaults.maxWidth)
        layout.setWidth(clamped, for: col)
        layout.saveWidths()
        log.debug("[AutoFit] col=\(col) optimal=\(Int(clamped))pt")
    }

    // MARK: - Restore Defaults

    private func restoreDefaults() {
        for col in ColumnID.allCases {
            if let idx = layout.columns.firstIndex(where: { $0.id == col }) {
                layout.columns[idx].isVisible = col.defaultVisible
                layout.columns[idx].width = col.defaultWidth
            }
        }
        layout.saveWidths()
    }
}

// MARK: - Sortable Header

/// Column header with separate sort arrow click target and title double-click for auto-fit.
/// Sort arrow shows bold black highlight on hover (same affordance as ResizableDivider).
struct SortableHeader: View {
    let title: String
    let icon: String?
    let sortKey: SortKeysEnum?
    let currentKey: SortKeysEnum
    let ascending: Bool
    /// Called when sort arrow is clicked
    let onSort: (() -> Void)?
    /// Called on double-click of the title area (auto-fit column width)
    let onAutoFit: (() -> Void)?

    init(
        title: String,
        icon: String? = nil,
        sortKey: SortKeysEnum?,
        currentKey: SortKeysEnum,
        ascending: Bool,
        onSort: (() -> Void)? = nil,
        onAutoFit: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.sortKey = sortKey
        self.currentKey = currentKey
        self.ascending = ascending
        self.onSort = onSort
        self.onAutoFit = onAutoFit
    }

    private var isActive: Bool {
        guard let sk = sortKey else { return false }
        return currentKey == sk
    }

    private var activeColor: Color {
        Color(nsColor: NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.7, alpha: 1.0))
    }

    var body: some View {
        HStack(spacing: 0) {
            // Title area — double-click for auto-fit
            titleArea
            Spacer(minLength: 0)
            // Sort arrow — single click for sort, hover highlight
            if sortKey != nil {
                SortArrowButton(
                    isActive: isActive,
                    ascending: ascending,
                    onSort: onSort
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    // MARK: - Title Area

    @ViewBuilder
    private var titleArea: some View {
        if let iconName = icon {
            // Icon header — centered in remaining space
            Image(systemName: iconName)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? activeColor : TableHeaderStyle.color)
                .help(title)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(TapGesture(count: 2).onEnded { onAutoFit?() })
        } else {
            // Text header — left aligned
            Text(title)
                .font(.system(size: 13, weight: isActive ? TableHeaderStyle.sortActiveWeight : .regular))
                .foregroundStyle(isActive ? activeColor : TableHeaderStyle.color)
                .padding(.leading, 2)
                .lineLimit(1)
                .contentShape(Rectangle())
                .highPriorityGesture(TapGesture(count: 2).onEnded { onAutoFit?() })
        }
    }
}

// MARK: - Sort Arrow Button

/// Clickable sort indicator with hover highlight (bold black, like ResizableDivider).
struct SortArrowButton: View {
    let isActive: Bool
    let ascending: Bool
    let onSort: (() -> Void)?

    @State private var isHovering = false

    private var arrowName: String {
        isActive
            ? (ascending ? "chevron.up" : "chevron.down")
            : "chevron.up.chevron.down"
    }

    private var arrowColor: Color {
        if isHovering {
            return Color.black
        }
        guard isActive else {
            return TableHeaderStyle.color.opacity(0.35)
        }
        return ascending
            ? Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1))
            : Color(#colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1))
    }

    var body: some View {
        Image(systemName: arrowName)
            .font(.system(size: isHovering ? 15 : (isActive ? 14 : 13), weight: isHovering ? .bold : .medium))
            .foregroundStyle(arrowColor)
            .shadow(color: isHovering ? Color.black.opacity(0.3) : .clear, radius: 1, x: 0, y: 0)
            .padding(.horizontal, 3)
            .contentShape(Rectangle().inset(by: -4))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovering = hovering
                }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onTapGesture {
                onSort?()
            }
    }
}
