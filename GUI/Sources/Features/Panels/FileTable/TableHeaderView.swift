    // TableHeaderView.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 27.01.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Sortable, resizable, draggable column headers. Right-click → context menu to toggle columns.
    //
    // Interaction model:
    //   - Click sort arrow icon → toggle sort direction
    //   - Double-click column title area → auto-fit column width to content
    //   - Drag divider between columns → resize
    //   - Drag column header → reorder (Name always pinned at index 0)
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
        var isFocused: Bool = false

        /// Column ID currently being dragged (for drop highlight)
        @State private var dragOverTargetID: ColumnID? = nil

        private var sortKey: SortKeysEnum { appState.sortKey }
        private var sortAscending: Bool { appState.bSortAscending }
        
        /// Header background color - warmWhite when focused
        private var headerBackgroundColor: Color {
            if isFocused {
                return ColorThemeStore.shared.activeTheme.warmWhite
            } else {
                return TableHeaderStyle.backgroundColor
            }
        }

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
                        min: spec.id.minDragWidth,
                        max: TableColumnDefaults.maxWidth,
                        onEnd: { layout.saveWidths() }
                    )
                    draggableColumnHeader(for: spec)
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 22)
            .padding(.vertical, 1)
            .background(headerBackgroundColor)
            .overlay(alignment: .bottom) {
                Rectangle()
                    // subtle grey‑blue separator similar to Finder column separators
                    .fill(Color(nsColor: NSColor(calibratedRed: 0.68, green: 0.72, blue: 0.80, alpha: 0.45)))
                    .frame(height: 0.5)
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

        // MARK: - Draggable Column Header

        private func draggableColumnHeader(for spec: ColumnSpec) -> some View {
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
                    .padding(.horizontal, TableColumnDefaults.cellPadding)
            .frame(width: spec.width, alignment: spec.id.alignment)
            .background(
                dragOverTargetID == spec.id
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .overlay(alignment: .leading) {
                if dragOverTargetID == spec.id {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2)
                }
            }
            .draggable(spec.id) {
                Text(spec.id.title)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
            }
            .dropDestination(for: ColumnID.self) { droppedItems, _ in
                guard let sourceID = droppedItems.first else { return false }
                layout.moveColumn(sourceID, before: spec.id)
                dragOverTargetID = nil
                return true
            } isTargeted: { targeted in
                dragOverTargetID = targeted ? spec.id : nil
            }
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
            case .dateCreated:
                texts = files.map { $0.creationDateFormatted }
                font = .systemFont(ofSize: 12)
            case .dateLastOpened:
                texts = files.map { $0.lastOpenedFormatted }
                font = .systemFont(ofSize: 12)
            case .dateAdded:
                texts = files.map { $0.dateAddedFormatted }
                font = .systemFont(ofSize: 12)
            case .group:
                texts = files.map { $0.groupNameFormatted }
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
            let clamped = Swift.min(Swift.max(optimal, col.minHeaderWidth), TableColumnDefaults.maxWidth)
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

        // MARK: - Title Area (double-click only → auto-fit, no sort)

        @ViewBuilder
        private var titleArea: some View {
            if let iconName = icon {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? activeColor : TableHeaderStyle.color)
                    .help(title)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onAutoFit?() }
                    .onTapGesture(count: 1) { /* swallow single tap — no sort here */ }
            } else {
                Text(title)
                    .font(.system(size: 13, weight: isActive ? TableHeaderStyle.sortActiveWeight : .regular))
                    .foregroundStyle(isActive ? activeColor : TableHeaderStyle.color)
                    .padding(.leading, 2)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onAutoFit?() }
                    .onTapGesture(count: 1) { /* swallow single tap — no sort here */ }
            }
        }
    }

    // MARK: - Sort Arrow Button

    /// Clickable sort indicator — macOS HIG style (Finder-like triangle).
    /// Shows small triangle when sorted, subtle indicator when not.
    struct SortArrowButton: View {
        let isActive: Bool
        let ascending: Bool
        let onSort: (() -> Void)?

        @State private var isHovering = false

        // macOS HIG: simple triangle indicator
        private var arrowName: String {
            if isActive {
                return ascending ? "chevron.up" : "chevron.down"
            } else {
                // Subtle indicator when not sorted by this column
                return "chevron.up.chevron.down"
            }
        }

        private var arrowColor: Color {
            if isHovering {
                return Color.primary
            }
            guard isActive else {
                return Color.secondary.opacity(0.5)
            }
            return Color.accentColor
        }

        var body: some View {
            Image(systemName: arrowName)
                .font(.system(size: isActive ? 12 : 11, weight: isActive ? .bold : .medium))
                .foregroundStyle(arrowColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
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
