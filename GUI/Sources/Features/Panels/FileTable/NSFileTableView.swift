// NSFileTableView.swift
// MiMiNavigator
//
// Created by Claude on 04.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: High-performance NSTableView wrapper for file lists.
//              Handles 100k+ files without lag using AppKit's native virtualization.

import AppKit
import SwiftUI
import FileModelKit

// MARK: - NSViewRepresentable Wrapper
struct NSFileTableView: NSViewRepresentable {
    let panelSide: PanelSide
    let files: [CustomFile]
    let filesVersion: Int  // Version number for change detection (O(1) instead of O(n) comparison)
    let sortKey: SortKeysEnum
    let sortAscending: Bool
    @Binding var selectedID: CustomFile.ID?
    let layout: ColumnLayoutModel
    let colorStore: ColorThemeStore
    let isFocused: Bool
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let onFileAction: (FileAction, CustomFile) -> Void
    let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
    let onMultiSelectionAction: (MultiSelectionAction) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        log.debug("[NSFileTableView] makeNSView panel=\(panelSide) files=\(files.count)")
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let tableView = NSTableView()
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = FilePanelStyle.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.allowsMultipleSelection = false
        tableView.allowsColumnReordering = false  // We use SwiftUI header for this
        tableView.allowsColumnResizing = false    // We use SwiftUI header for this
        tableView.allowsColumnSelection = false
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.gridStyleMask = .solidVerticalGridLineMask
        tableView.headerView = nil  // We use our own SwiftUI header
        tableView.focusRingType = .none
        
        // Setup columns based on layout
        setupColumns(tableView: tableView, layout: layout)
        
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        
        // Double-click action
        tableView.doubleAction = #selector(Coordinator.tableViewDoubleClick(_:))
        tableView.target = context.coordinator
        
        // Register for drag and drop
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        scrollView.documentView = tableView
        
        // Initialize coordinator state
        context.coordinator.tableView = tableView
        context.coordinator.updateFiles(files, version: filesVersion, sortKey: sortKey, sortAscending: sortAscending)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        
        let coordinator = context.coordinator
        
        // Update parent reference (closures may have changed)
        coordinator.parent = self
        
        // Check if files changed using version number (O(1)!)
        let filesChanged = coordinator.lastVersion != filesVersion
        let sortChanged = coordinator.lastSortKey != sortKey || coordinator.lastSortAscending != sortAscending
        
        if filesChanged || sortChanged {
            log.debug("[NSFileTableView] updateNSView files changed: v\(coordinator.lastVersion) → v\(filesVersion), count=\(files.count), sortChanged=\(sortChanged)")
            coordinator.updateFiles(files, version: filesVersion, sortKey: sortKey, sortAscending: sortAscending)
            tableView.reloadData()
        }
        
        // Update selection if changed externally
        let currentSelection = coordinator.lastSelectedID
        if currentSelection != selectedID {
            coordinator.lastSelectedID = selectedID
            if let id = selectedID, let idx = coordinator.indexByID[id] {
                let indexSet = IndexSet(integer: idx)
                if tableView.selectedRowIndexes != indexSet {
                    tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
                    tableView.scrollRowToVisible(idx)
                }
            } else if selectedID == nil {
                tableView.deselectAll(nil)
            }
        }
        
        // Update focus state
        if coordinator.isFocused != isFocused {
            coordinator.isFocused = isFocused
            // Refresh visible rows to update selection color
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            if visibleRows.length > 0 {
                tableView.reloadData(forRowIndexes: IndexSet(integersIn: visibleRows.location..<(visibleRows.location + visibleRows.length)),
                                     columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))
            }
        }
    }
    
    private func setupColumns(tableView: NSTableView, layout: ColumnLayoutModel) {
        // Remove existing columns
        for col in tableView.tableColumns.reversed() {
            tableView.removeTableColumn(col)
        }
        
        // Add columns based on layout
        for spec in layout.visibleColumns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(spec.id.rawValue))
            column.title = spec.id.title
            column.width = spec.id == .name ? 250 : spec.width
            column.minWidth = 40
            column.maxWidth = spec.id == .name ? 2000 : 500
            column.isEditable = false
            column.resizingMask = spec.id == .name ? .autoresizingMask : .userResizingMask
            
            tableView.addTableColumn(column)
        }
    }
    
    // MARK: - Coordinator
    @MainActor
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: NSFileTableView
        weak var tableView: NSTableView?
        
        // File data
        private(set) var files: [CustomFile] = []
        private(set) var indexByID: [CustomFile.ID: Int] = [:]
        private(set) var lastVersion: Int = -1
        private(set) var lastSortKey: SortKeysEnum = .name
        private(set) var lastSortAscending: Bool = true
        
        // Selection tracking
        var lastSelectedID: CustomFile.ID?
        var isFocused: Bool = false
        
        // Suppress selection callback during programmatic changes
        private var suppressSelectionCallback = false
        
        init(_ parent: NSFileTableView) {
            self.parent = parent
            super.init()
        }
        
        /// Update files and rebuild index. Called when version or sort changes.
        func updateFiles(_ newFiles: [CustomFile], version: Int, sortKey: SortKeysEnum, sortAscending: Bool) {
            files = newFiles
            lastVersion = version
            lastSortKey = sortKey
            lastSortAscending = sortAscending
            rebuildIndex()
        }
        
        private func rebuildIndex() {
            indexByID.removeAll(keepingCapacity: true)
            for (idx, file) in files.enumerated() {
                indexByID[file.id] = idx
            }
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            files.count
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < files.count, let columnID = tableColumn?.identifier.rawValue else { return nil }
            let file = files[row]
            guard let colID = ColumnID(rawValue: columnID) else { return nil }
            
            // Create or reuse cell
            let cellIdentifier = NSUserInterfaceItemIdentifier("Cell_\(columnID)")
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
            
            if cellView == nil {
                cellView = createCellView(identifier: cellIdentifier, columnID: colID)
            }
            
            // Configure content
            configureCellView(cellView!, file: file, columnID: colID, row: row, tableView: tableView)
            
            return cellView
        }
        
        private func createCellView(identifier: NSUserInterfaceItemIdentifier, columnID: ColumnID) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = identifier
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.cell?.truncatesLastVisibleLine = true
            textField.drawsBackground = false
            textField.isBordered = false
            textField.isEditable = false
            
            cell.addSubview(textField)
            cell.textField = textField
            
            // Add icon image view for name column
            if columnID == .name {
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.imageScaling = .scaleProportionallyUpOrDown
                cell.addSubview(imageView)
                cell.imageView = imageView
                
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            }
            
            return cell
        }
        
        private func configureCellView(_ cell: NSTableCellView, file: CustomFile, columnID: ColumnID, row: Int, tableView: NSTableView) {
            // Text content
            let text = cellText(for: columnID, file: file)
            cell.textField?.stringValue = text
            
            // Font
            cell.textField?.font = columnID == .permissions
                ? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                : NSFont.systemFont(ofSize: 12)
            
            // Alignment
            switch columnID.alignment {
            case .trailing:
                cell.textField?.alignment = .right
            case .center:
                cell.textField?.alignment = .center
            default:
                cell.textField?.alignment = .left
            }
            
            // Icon for name column
            if columnID == .name {
                cell.imageView?.image = iconForFile(file)
            }
            
            // Text color
            let isSelected = tableView.selectedRowIndexes.contains(row)
            let theme = parent.colorStore.activeTheme
            
            if isSelected && isFocused {
                cell.textField?.textColor = .white
            } else if ParentDirectoryEntry.isParentEntry(file) {
                cell.textField?.textColor = .secondaryLabelColor
            } else if file.isHidden {
                cell.textField?.textColor = NSColor(theme.hiddenFileColor)
            } else {
                cell.textField?.textColor = NSColor(columnID.columnColor(from: theme))
            }
        }
        
        private func iconForFile(_ file: CustomFile) -> NSImage? {
            if ParentDirectoryEntry.isParentEntry(file) {
                return NSImage(systemSymbolName: "arrow.up.circle", accessibilityDescription: "Parent")
            }
            // Use system icon
            return NSWorkspace.shared.icon(forFile: file.urlValue.path)
        }
        
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rowView = FileTableRowView()
            rowView.isFocused = isFocused
            rowView.colorStore = parent.colorStore
            return rowView
        }
        
        // MARK: - Selection
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !suppressSelectionCallback else { return }
            guard let tableView = notification.object as? NSTableView else { return }
            
            let selectedRow = tableView.selectedRow
            if selectedRow >= 0 && selectedRow < files.count {
                let file = files[selectedRow]
                lastSelectedID = file.id
                parent.selectedID = file.id
                parent.onSelect(file)
            } else {
                lastSelectedID = nil
                parent.selectedID = nil
            }
        }
        
        @objc func tableViewDoubleClick(_ sender: NSTableView) {
            let clickedRow = sender.clickedRow
            guard clickedRow >= 0 && clickedRow < files.count else { return }
            let file = files[clickedRow]
            parent.onDoubleClick(file)
        }
        
        // MARK: - Drag and Drop
        
        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row < files.count else { return nil }
            return files[row].urlValue as NSURL
        }
        
        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            if dropOperation == .on && row < files.count {
                let targetFile = files[row]
                if targetFile.isDirectory {
                    return .move
                }
            }
            return []
        }
        
        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            // TODO: Implement drop handling via DragDropManager
            return false
        }
        
        // MARK: - Helpers
        
        private func cellText(for col: ColumnID, file: CustomFile) -> String {
            if ParentDirectoryEntry.isParentEntry(file) && col != .name {
                return ""
            }
            
            switch col {
            case .name: return file.nameStr
            case .dateModified: return file.modifiedDateFormatted
            case .size: return file.fileSizeFormatted
            case .kind: return file.kindFormatted
            case .permissions: return file.permissionsFormatted
            case .owner: return file.ownerFormatted
            case .childCount: return file.childCountFormatted
            case .dateCreated: return file.creationDateFormatted
            case .dateLastOpened: return file.lastOpenedFormatted
            case .dateAdded: return file.dateAddedFormatted
            case .group: return file.groupNameFormatted
            }
        }
    }
}

// MARK: - Custom Row View for selection highlighting
class FileTableRowView: NSTableRowView {
    var isFocused: Bool = false
    var colorStore: ColorThemeStore?
    
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        
        let theme = colorStore?.activeTheme ?? ColorTheme.defaultTheme
        let color = isFocused
            ? NSColor(theme.selectionActive)
            : NSColor(theme.selectionInactive)
        
        color.setFill()
        let selectionRect = bounds.insetBy(dx: 4, dy: 1)
        let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
        path.fill()
    }
    
    override var isEmphasized: Bool {
        get { isFocused }
        set { }
    }
    
    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        isSelected && isFocused ? .emphasized : .normal
    }
}
