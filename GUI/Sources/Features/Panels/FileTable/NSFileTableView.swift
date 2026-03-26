    // NSFileTableView.swift
    // MiMiNavigator
    //
    // Multi-column NSTableView synced with SwiftUI TableHeaderView.

    import AppKit
    import FavoritesKit
    import FileModelKit
    import LogKit
    import SwiftUI

    // MARK: - NSViewRepresentable
    struct NSFileTableView: NSViewRepresentable {
        let panelSide: FavPanelSide
        let files: [CustomFile]
        let filesVersion: Int
        let sortKey: SortKeysEnum
        let sortAscending: Bool
        @Binding var selectedID: CustomFile.ID?
        let layout: ColumnLayoutModel
        let colorStore: ColorThemeStore
        let isFocused: Bool
        let onSelect: (CustomFile) -> Void
        let onDoubleClick: (CustomFile) -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSScrollView()
            ScrollBarSetup.apply(to: scrollView)

            let tableView = ClickTrackingTableView()
            tableView.style = .plain
            tableView.usesAlternatingRowBackgroundColors = false
            tableView.rowHeight = FilePanelStyle.rowHeight
            tableView.intercellSpacing = NSSize(width: 0, height: 0)
            tableView.allowsMultipleSelection = true
            tableView.allowsColumnReordering = false
            tableView.allowsColumnResizing = false
            tableView.allowsColumnSelection = false
            tableView.columnAutoresizingStyle = .noColumnAutoresizing
            tableView.gridStyleMask = .solidVerticalGridLineMask
            tableView.gridColor = NSColor.separatorColor.withAlphaComponent(0.4)
            tableView.focusRingType = .none
            tableView.headerView = nil  // SwiftUI header

            setupColumns(tableView: tableView)

            tableView.delegate = context.coordinator
            tableView.dataSource = context.coordinator

            tableView.doubleAction = #selector(Coordinator.tableViewDoubleClick(_:))
            tableView.target = context.coordinator

            tableView.registerForDraggedTypes([.fileURL])
            tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
            tableView.setDraggingSourceOperationMask(.move, forLocal: true)

            // Context menu
            let menu = NSMenu()
            menu.delegate = context.coordinator
            tableView.menu = menu

            scrollView.documentView = tableView

            context.coordinator.tableView = tableView
            context.coordinator.scrollView = scrollView
            context.coordinator.updateFiles(files, version: filesVersion)

            updateBackgroundColor(scrollView: scrollView, tableView: tableView)

            return scrollView
        }

        func updateNSView(_ scrollView: NSScrollView, context: Context) {
            guard let tableView = scrollView.documentView as? NSTableView else { return }
            let coord = context.coordinator
            coord.parent = self

            // Sync columns
            syncColumns(tableView: tableView)

            // Files changed?
            let filesChanged = coord.lastVersion != filesVersion
            if filesChanged {
                coord.updateFiles(files, version: filesVersion)
                tableView.reloadData()
            }

            // Selection
            if coord.lastSelectedID != selectedID {
                coord.lastSelectedID = selectedID
                if let id = selectedID, let idx = coord.indexByID[id] {
                    tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.15
                        context.allowsImplicitAnimation = true
                        tableView.scrollRowToVisible(idx)
                    })
                } else {
                    tableView.deselectAll(nil)
                }
            }

            // Focus
            if coord.isFocused != isFocused {
                coord.isFocused = isFocused
                updateBackgroundColor(scrollView: scrollView, tableView: tableView)
                tableView.reloadData()
            }
        }

        private func setupColumns(tableView: NSTableView) {
            for col in tableView.tableColumns.reversed() {
                tableView.removeTableColumn(col)
            }

            for spec in layout.visibleColumns {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(spec.id.rawValue))
                column.width = spec.id == .name ? 200 : spec.width  // Name will be calculated
                column.minWidth = 30
                column.maxWidth = 2000
                column.isEditable = false
                column.resizingMask = []
                tableView.addTableColumn(column)
            }
        }

        private func syncColumns(tableView: NSTableView) {
            let visibleSpecs = layout.visibleColumns

            // Check if columns need rebuild
            let currentIDs = tableView.tableColumns.map { $0.identifier.rawValue }
            let layoutIDs = visibleSpecs.map { $0.id.rawValue }

            if currentIDs != layoutIDs {
                setupColumns(tableView: tableView)
                tableView.reloadData()
                return
            }

            // SwiftUI header layout:
            // [Name flexible] | div(1pt) | [col1 width] | div(1pt) | [col2 width] | ...
            //
            // Total width = Name + n*dividers + sum(fixed widths)
            // Where n = number of fixed columns (each has a divider before it)
            //
            // NSTableView intercellSpacing.width = 0, grid lines drawn inside columns.
            // To match: we need Name = scrollWidth - sum(fixed) - n*dividers
            //           But NSTableView doesn't have dividers, so we add 1pt to each
            //           fixed column to account for the SwiftUI divider before it.

            let scrollWidth = tableView.enclosingScrollView?.contentSize.width ?? tableView.bounds.width
            let fixedSpecs = visibleSpecs.filter { $0.id != .name }
            let fixedColumnsWidth = fixedSpecs.reduce(0) { $0 + $1.width }
            let dividersCount = fixedSpecs.count  // one divider before each fixed column
            let dividersWidth = CGFloat(dividersCount) * 1.0

            // Name takes remaining space after fixed columns and dividers
            let nameWidth = max(100, scrollWidth - fixedColumnsWidth - dividersWidth)

            // Sync widths - fixed columns need -4pt adjustment to align with SwiftUI header
            for (i, spec) in visibleSpecs.enumerated() {
                guard i < tableView.tableColumns.count else { break }
                let col = tableView.tableColumns[i]
                let targetWidth = spec.id == .name ? nameWidth : (spec.width - 4.0)

                if abs(col.width - targetWidth) > 0.5 {
                    col.width = targetWidth
                }
            }

            tableView.tile()
        }

        private func updateBackgroundColor(scrollView: NSScrollView, tableView: NSTableView) {
            let theme = colorStore.activeTheme
            let bg = isFocused ? NSColor(theme.warmWhite) : NSColor.controlBackgroundColor
            scrollView.backgroundColor = bg
            scrollView.drawsBackground = true
            tableView.backgroundColor = bg
        }

        // MARK: - Coordinator
        // → Extracted to TableView/NSFileTableViewCoordinator.swift
    }
