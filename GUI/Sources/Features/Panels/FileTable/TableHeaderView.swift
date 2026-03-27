// TableHeaderView.swift
// MiMiNavigator — Sortable, resizable column headers (Finder-style).
// Topology: [Name][div][col1][div][col2]...[colN]
// Divider controls column to its LEFT. Drag right → left column grows.

import FileModelKit
import SwiftUI

struct TableHeaderView: View {

    @Environment(AppState.self) var appState
    let panelSide: FavPanelSide
    @Bindable var layout: ColumnLayoutModel
    var isFocused: Bool = false

    @State private var dragOverTargetID: ColumnID? = nil

    // MARK: - Computed Properties

    private var sortKey: SortKeysEnum { appState.sortKey }
    private var sortAscending: Bool { appState.bSortAscending }
    private var fixedCols: [ColumnSpec] { layout.fixedColumns }
    private var maxRight: CGFloat { layout.containerWidth > 5 ? layout.containerWidth - 5 : 9999 }

    private var headerBg: Color {
        isFocused
        ? ColorThemeStore.shared.activeTheme.warmWhite
        : TableHeaderStyle.backgroundColor
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            containerWidthProbe
            columnHeaders
        }
        .frame(height: 22)
        .padding(.vertical, 1)
        .background(headerBg)
        .overlay { headerBorder }
        .shadow(color: .black.opacity(0.10), radius: 1, x: 0, y: 1)
        .contextMenu { columnToggleMenu }
    }

    // MARK: - Container Width Probe

    private var containerWidthProbe: some View {
        GeometryReader { geo in
            Color.clear
            .onAppear { updateContainerWidth(geo.size.width) }
            .onChange(of: geo.size.width) { _, w in updateContainerWidth(w) }
        }
    }

    private func updateContainerWidth(_ width: CGFloat) {
        layout.containerWidth = width
        layout.updateNameWidthForContainer()
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(alignment: .center, spacing: 0) {
            nameColumnHeader
            nameDivider()

            ForEach(fixedCols.indices, id: \.self) { i in
                let spec = fixedCols[i]
                fixedColumnHeader(for: spec)
                if i < fixedCols.count - 1 {
                    columnDivider(for: spec)
                }
            }
        }
        .onPreferenceChange(ColumnWidthPreferenceKey.self) { syncColumnWidths(from: $0) }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var headerBorder: some View {
        RoundedRectangle(cornerRadius: 3)
        .stroke(Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.32, alpha: 0.50)), lineWidth: 0.75)
        .allowsHitTesting(false)
    }

    // MARK: - Name Column Header

    private var nameColumnHeader: some View {
        SortableHeader(
            title: ColumnID.name.title,
            icon: ColumnID.name.icon,
            sortKey: ColumnID.name.sortKey,
            currentKey: sortKey,
            ascending: sortAscending,
            onSort: { toggleSort(.name) },
            onAutoFit: nil
        )
        .frame(width: layout.nameWidth, alignment: .leading)
        .padding(.horizontal, 4)
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
                let w = autoFitWidth(for: spec.id)
                layout.setWidth(w, for: spec.id)
                layout.saveWidths()
            }
        )
        .padding(.horizontal, TableColumnDefaults.cellPadding)
        .frame(width: spec.width, alignment: spec.id.alignment)
        .background(dragTargetBackground(for: spec.id))
        .overlay(alignment: .leading) { dragTargetIndicator(for: spec.id) }
        .background(geoMeasurement(for: spec))
        .draggable(spec.id) { dragPreview(for: spec) }
        .dropDestination(for: ColumnID.self) { items, _ in
            handleDrop(items: items, target: spec.id)
        } isTargeted: { targeted in
            dragOverTargetID = targeted ? spec.id : nil
        }
    }

    // MARK: - Dividers

    private func nameDivider() -> some View {
        let effectiveMax = layout.containerWidth > 5
            ? layout.effectiveMaxNameWidth
            : CGFloat(9999)
        return ResizableDivider(
            width: Binding(
                get: { layout.nameWidth },
                set: { layout.nameWidth = $0 }
            ),
            min: 60,
            max: effectiveMax,
            onEnd: { layout.saveWidths() },
            onAutoFit: { autoFitWidth(for: .name) }
        )
    }

    private func columnDivider(for spec: ColumnSpec) -> some View {
        ResizableDivider(
            width: Binding(
                get: { spec.width },
                set: { layout.setWidth($0, for: spec.id) }
            ),
            min: spec.id.minDragWidth,
            max: Swift.min(spec.id.maxWidth, maxRight),
            onEnd: { layout.saveWidths() },
            onAutoFit: { autoFitWidth(for: spec.id) }
        )
    }

    // MARK: - Geo Sync

    private func geoMeasurement(for spec: ColumnSpec) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ColumnWidthPreferenceKey.self,
                value: [ColumnWidthEntry(id: spec.id, width: geo.size.width)]
            )
        }
    }

    private func syncColumnWidths(from entries: [ColumnWidthEntry]) {
        for entry in entries {
            guard let idx = layout.columns.firstIndex(where: { $0.id == entry.id }) else { continue }
            let rounded = entry.width.rounded()
            if abs(layout.columns[idx].width - rounded) > 0.5 {
                layout.columns[idx].width = rounded
            }
        }
    }

    // MARK: - Drag & Drop UI

    private func dragTargetBackground(for id: ColumnID) -> Color {
        dragOverTargetID == id ? Color.accentColor.opacity(0.15) : .clear
    }

    @ViewBuilder
    private func dragTargetIndicator(for id: ColumnID) -> some View {
        if dragOverTargetID == id {
            Rectangle().fill(Color.accentColor).frame(width: 2)
        }
    }

    private func dragPreview(for spec: ColumnSpec) -> some View {
        Text(spec.id.title)
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
    }

    private func handleDrop(items: [ColumnID], target: ColumnID) -> Bool {
        guard let src = items.first else { return false }
        layout.moveColumn(src, before: target)
        dragOverTargetID = nil
        return true
    }

    // MARK: - Sort

    private func toggleSort(_ col: ColumnID) {
        guard let key = col.sortKey else { return }
        appState.focusedPanel = panelSide
        if sortKey == key {
            appState.bSortAscending.toggle()
        } else {
            appState.sortKey = key
            appState.bSortAscending = true
        }
        appState.updateSorting()
    }

    // MARK: - Auto-fit

    @discardableResult
    func autoFitWidth(for col: ColumnID) -> CGFloat {
        let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        guard !files.isEmpty else { return col.defaultWidth }

        let (texts, font) = textsAndFont(for: col, files: files)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let maxTextW = texts.reduce(CGFloat(0)) {
            Swift.max($0, ($1 as NSString).size(withAttributes: attrs).width)
        }
        let optimal = ceil(maxTextW + 2 * TableColumnDefaults.cellPadding + 5)
        return optimal.clamped(to: col.minDragWidth...col.maxWidth)
    }

    private func textsAndFont(for col: ColumnID, files: [CustomFile]) -> ([String], NSFont) {
        switch col {
        case .size: return (files.map { $0.fileSizeFormatted }, .systemFont(ofSize: 12))
        case .dateModified: return (files.map { $0.modifiedDateFormatted }, .systemFont(ofSize: 12))
        case .kind: return (files.map { $0.kindFormatted }, .systemFont(ofSize: 12))
        case .permissions: return (files.map { $0.permissionsFormatted }, .monospacedSystemFont(ofSize: 11, weight: .regular))
        case .owner: return (files.map { $0.ownerFormatted }, .systemFont(ofSize: 12))
        case .childCount: return (files.map { $0.childCountFormatted }, .systemFont(ofSize: 12))
        case .dateCreated: return (files.map { $0.creationDateFormatted }, .systemFont(ofSize: 12))
        case .dateLastOpened: return (files.map { $0.lastOpenedFormatted }, .systemFont(ofSize: 12))
        case .dateAdded: return (files.map { $0.dateAddedFormatted }, .systemFont(ofSize: 12))
        case .group: return (files.map { $0.groupNameFormatted }, .systemFont(ofSize: 12))
        case .name: return ([], .systemFont(ofSize: 12))
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var columnToggleMenu: some View {
        ForEach(layout.columns) { spec in
            if !spec.id.isRequired {
                Button {
                    layout.toggle(spec.id)
                } label: {
                    Label(spec.id.title, systemImage: spec.isVisible ? "checkmark" : "")
                }
            }
        }
        Divider()

        // Auto-fit toggle — synced with ~/.mimi/preferences.json
        let autoFitOn = UserPreferences.shared.snapshot.autoFitColumnsOnNavigate
        Button {
            let newVal = !autoFitOn
            UserPreferences.shared.snapshot.autoFitColumnsOnNavigate = newVal
            UserPreferences.shared.save()
            if newVal {
                let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
                ColumnAutoFitter.autoFitAll(layout: layout, files: files)
            }
        } label: {
            Label("Auto-fit columns on navigate", systemImage: autoFitOn ? "checkmark" : "")
        }

        Divider()
        Button("Restore Defaults") { restoreDefaults() }
    }

    private func restoreDefaults() {
        for col in ColumnID.allCases {
            guard let idx = layout.columns.firstIndex(where: { $0.id == col }) else { continue }
            layout.columns[idx].isVisible = col.defaultVisible
            layout.columns[idx].width = col.defaultWidth
        }
        layout.saveWidths()
    }
}

// MARK: - CGFloat Extension

extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
