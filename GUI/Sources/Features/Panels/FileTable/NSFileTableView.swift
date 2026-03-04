// NSFileTableView.swift
// MiMiNavigator
//
// Multi-column NSTableView synced with SwiftUI TableHeaderView.

import AppKit
import SwiftUI
import FileModelKit
import FavoritesKit

// MARK: - NSViewRepresentable
struct NSFileTableView: NSViewRepresentable {
    let panelSide: PanelSide
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
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let tableView = NSTableView()
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowHeight = FilePanelStyle.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.allowsMultipleSelection = false
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
    @MainActor
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate {
        var parent: NSFileTableView
        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?
        
        var files: [CustomFile] = []
        var indexByID: [CustomFile.ID: Int] = [:]
        var lastVersion: Int = -1
        var lastSelectedID: CustomFile.ID?
        var isFocused: Bool = false
        
        init(_ parent: NSFileTableView) {
            self.parent = parent
            super.init()
        }
        
        func updateFiles(_ newFiles: [CustomFile], version: Int) {
            files = newFiles
            lastVersion = version
            indexByID.removeAll(keepingCapacity: true)
            for (i, f) in files.enumerated() { indexByID[f.id] = i }
        }
        
        func numberOfRows(in tableView: NSTableView) -> Int { files.count }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < files.count,
                  let colRaw = tableColumn?.identifier.rawValue,
                  let colID = ColumnID(rawValue: colRaw) else { return nil }
            
            let file = files[row]
            let cellID = NSUserInterfaceItemIdentifier("Cell_\(colRaw)")
            
            var cell = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView
            if cell == nil {
                cell = createCell(identifier: cellID, columnID: colID)
            }
            
            configureCell(cell!, file: file, columnID: colID, row: row, tableView: tableView)
            return cell
        }
        
        private func createCell(identifier: NSUserInterfaceItemIdentifier, columnID: ColumnID) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = identifier
            
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingTail
            tf.drawsBackground = false
            tf.isBordered = false
            tf.isEditable = false
            tf.font = NSFont.systemFont(ofSize: 13)
            cell.addSubview(tf)
            cell.textField = tf
            
            if columnID == .name {
                let iv = NSImageView()
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.imageScaling = .scaleProportionallyUpOrDown
                cell.addSubview(iv)
                cell.imageView = iv
                
                NSLayoutConstraint.activate([
                    iv.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    iv.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    iv.widthAnchor.constraint(equalToConstant: 16),
                    iv.heightAnchor.constraint(equalToConstant: 16),
                    tf.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 4),
                    tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            }
            
            return cell
        }
        
        private func configureCell(_ cell: NSTableCellView, file: CustomFile, columnID: ColumnID, row: Int, tableView: NSTableView) {
            cell.textField?.stringValue = text(for: columnID, file: file)
            cell.textField?.font = columnID == .permissions
                ? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                : NSFont.systemFont(ofSize: 13)
            cell.textField?.alignment = columnID.alignment == .trailing ? .right : .left
            
            if columnID == .name {
                cell.imageView?.image = ParentDirectoryEntry.isParentEntry(file)
                    ? NSImage(systemSymbolName: "arrow.up.circle", accessibilityDescription: nil)
                    : NSWorkspace.shared.icon(forFile: file.urlValue.path)
            }
            
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
        
        private func text(for col: ColumnID, file: CustomFile) -> String {
            if ParentDirectoryEntry.isParentEntry(file) && col != .name { return "" }
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
        
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            let rv = FileTableRowView()
            rv.isFocused = isFocused
            rv.colorStore = parent.colorStore
            rv.rowIndex = row
            return rv
        }
        
        func tableViewSelectionDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTableView else { return }
            let row = tv.selectedRow
            if row >= 0 && row < files.count {
                let f = files[row]
                lastSelectedID = f.id
                parent.selectedID = f.id
                parent.onSelect(f)
            } else {
                lastSelectedID = nil
                parent.selectedID = nil
            }
        }
        
        @objc func tableViewDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0 && row < files.count else { return }
            parent.onDoubleClick(files[row])
        }
        
        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row < files.count else { return nil }
            return files[row].urlValue as NSURL
        }
        
        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
            if op == .on && row < files.count && files[row].isDirectory { return .move }
            return []
        }
        
        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool { false }
        
        // MARK: - NSMenuDelegate
        
        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            
            guard let tv = tableView else { return }
            let clickedRow = tv.clickedRow
            
            guard clickedRow >= 0 && clickedRow < files.count else {
                // Click on empty area - panel background menu
                addMenuItem(menu, title: "New Folder", action: #selector(menuNewFolder), key: "N")
                addMenuItem(menu, title: "Refresh", action: #selector(menuRefresh), key: "r")
                menu.addItem(NSMenuItem.separator())
                addMenuItem(menu, title: "Paste", action: #selector(menuPaste), key: "v")
                return
            }
            
            let file = files[clickedRow]
            
            // Select row if not selected
            if !tv.selectedRowIndexes.contains(clickedRow) {
                tv.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            }
            
            if file.isDirectory {
                buildDirectoryMenu(menu, file: file)
            } else {
                buildFileMenu(menu, file: file)
            }
        }
        
        private func buildFileMenu(_ menu: NSMenu, file: CustomFile) {
            // SECTION 1: Open
            addMenuItem(menu, title: "Open", action: #selector(menuOpen), key: "", icon: "arrow.up.doc")
            addMenuItem(menu, title: "Open With...", action: #selector(menuOpenWith), key: "", icon: "arrow.up.right.square")
            addMenuItem(menu, title: "Quick Look", action: #selector(menuQuickLook), key: " ", icon: "eye")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 2: Edit
            addMenuItem(menu, title: "Cut", action: #selector(menuCut), key: "x", icon: "scissors")
            addMenuItem(menu, title: "Copy", action: #selector(menuCopy), key: "c", icon: "doc.on.doc")
            addMenuItem(menu, title: "Copy as Pathname", action: #selector(menuCopyPath), key: "", icon: "doc.on.doc.fill")
            addMenuItem(menu, title: "Paste", action: #selector(menuPaste), key: "v", icon: "doc.on.clipboard")
            addMenuItem(menu, title: "Duplicate", action: #selector(menuDuplicate), key: "d", icon: "plus.square.on.square")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 3: Operations
            addMenuItem(menu, title: "Compress", action: #selector(menuCompress), key: "", icon: "archivebox")
            addMenuItem(menu, title: "Share...", action: #selector(menuShare), key: "", icon: "square.and.arrow.up")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 4: Navigation
            addMenuItem(menu, title: "Show in Finder", action: #selector(menuRevealInFinder), key: "", icon: "folder")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 5: Rename & Delete
            addMenuItem(menu, title: "Rename...", action: #selector(menuRename), key: "", icon: "pencil")
            addMenuItem(menu, title: "Move to Trash", action: #selector(menuTrash), key: "", icon: "trash")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 6: Info
            addMenuItem(menu, title: "Get Info", action: #selector(menuGetInfo), key: "i", icon: "info.circle")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 7: Favorites
            addMenuItem(menu, title: "Add to Favorites", action: #selector(menuAddToFavorites), key: "", icon: "star")
        }
        
        private func buildDirectoryMenu(_ menu: NSMenu, file: CustomFile) {
            // SECTION 1: Navigation
            addMenuItem(menu, title: "Open", action: #selector(menuOpen), key: "", icon: "folder")
            addMenuItem(menu, title: "Open in New Tab", action: #selector(menuOpenInNewTab), key: "t", icon: "plus.square.on.square")
            addMenuItem(menu, title: "Open in Finder", action: #selector(menuRevealInFinder), key: "", icon: "folder.badge.gear")
            addMenuItem(menu, title: "Open in Terminal", action: #selector(menuOpenInTerminal), key: "", icon: "terminal")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 2: Edit
            addMenuItem(menu, title: "Cut", action: #selector(menuCut), key: "x", icon: "scissors")
            addMenuItem(menu, title: "Copy", action: #selector(menuCopy), key: "c", icon: "doc.on.doc")
            addMenuItem(menu, title: "Copy as Pathname", action: #selector(menuCopyPath), key: "", icon: "doc.on.doc.fill")
            addMenuItem(menu, title: "Paste", action: #selector(menuPaste), key: "v", icon: "doc.on.clipboard")
            addMenuItem(menu, title: "Duplicate", action: #selector(menuDuplicate), key: "d", icon: "plus.square.on.square")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 3: Operations
            addMenuItem(menu, title: "Compress", action: #selector(menuCompress), key: "", icon: "archivebox")
            addMenuItem(menu, title: "Share...", action: #selector(menuShare), key: "", icon: "square.and.arrow.up")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 4: Rename & Delete
            addMenuItem(menu, title: "Rename...", action: #selector(menuRename), key: "", icon: "pencil")
            addMenuItem(menu, title: "Move to Trash", action: #selector(menuTrash), key: "", icon: "trash")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 5: Info
            addMenuItem(menu, title: "Get Info", action: #selector(menuGetInfo), key: "i", icon: "info.circle")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 6: Cross-panel
            addMenuItem(menu, title: "Open on Other Panel", action: #selector(menuOpenOnOtherPanel), key: "", icon: "rectangle.split.2x1")
            menu.addItem(NSMenuItem.separator())
            
            // SECTION 7: Favorites
            addMenuItem(menu, title: "Add to Favorites", action: #selector(menuAddToFavorites), key: "", icon: "star")
        }
        
        private func addMenuItem(_ menu: NSMenu, title: String, action: Selector, key: String, icon: String? = nil) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            if let iconName = icon, let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                item.image = img
            }
            menu.addItem(item)
        }
        
        private var clickedFile: CustomFile? {
            guard let tv = tableView, tv.clickedRow >= 0, tv.clickedRow < files.count else { return nil }
            return files[tv.clickedRow]
        }
        
        @objc private func menuOpen() {
            guard let file = clickedFile else { return }
            parent.onDoubleClick(file)
        }
        
        @objc private func menuOpenWith() {
            guard let file = clickedFile else { return }
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            panel.message = "Choose application to open the file"
            if panel.runModal() == .OK, let appURL = panel.url {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([file.urlValue], withApplicationAt: appURL, configuration: config)
            }
        }
        
        @objc private func menuQuickLook() {
            guard let file = clickedFile else { return }
            // Trigger Quick Look via QLPreviewPanel
            NSWorkspace.shared.activateFileViewerSelecting([file.urlValue])
        }
        
        @objc private func menuOpenInNewTab() {
            // TODO: implement open in new tab
        }
        
        @objc private func menuOpenInTerminal() {
            guard let file = clickedFile else { return }
            let escapedPath = file.pathStr.replacingOccurrences(of: "'", with: "'\\''")
            let script = "tell application \"Terminal\" to do script \"cd '\(escapedPath)'\""
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                NSWorkspace.shared.openApplication(at: terminalURL, configuration: NSWorkspace.OpenConfiguration())
            }
        }
        
        @objc private func menuCut() {
            guard let file = clickedFile else { return }
            ClipboardManager.shared.cut(files: [file], from: parent.panelSide)
        }
        
        @objc private func menuCopy() {
            guard let file = clickedFile else { return }
            ClipboardManager.shared.copy(files: [file], from: parent.panelSide)
        }
        
        @objc private func menuCopyPath() {
            guard let file = clickedFile else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(file.pathStr, forType: .string)
        }
        
        @objc private func menuPaste() {
            // TODO: implement paste via ClipboardManager
        }
        
        @objc private func menuDuplicate() {
            guard let file = clickedFile else { return }
            let fm = FileManager.default
            let dir = file.urlValue.deletingLastPathComponent()
            let baseName = file.urlValue.deletingPathExtension().lastPathComponent
            let ext = file.urlValue.pathExtension
            var counter = 2
            var newURL = dir.appendingPathComponent(ext.isEmpty ? "\(baseName) copy" : "\(baseName) copy.\(ext)")
            while fm.fileExists(atPath: newURL.path) {
                newURL = dir.appendingPathComponent(ext.isEmpty ? "\(baseName) copy \(counter)" : "\(baseName) copy \(counter).\(ext)")
                counter += 1
            }
            try? fm.copyItem(at: file.urlValue, to: newURL)
        }
        
        @objc private func menuCompress() {
            guard let file = clickedFile else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = file.urlValue.deletingLastPathComponent()
            process.arguments = ["-r", "\(file.nameStr).zip", file.nameStr]
            try? process.run()
        }
        
        @objc private func menuShare() {
            guard let file = clickedFile else { return }
            let picker = NSSharingServicePicker(items: [file.urlValue])
            if let view = tableView {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            }
        }
        
        @objc private func menuRevealInFinder() {
            guard let file = clickedFile else { return }
            NSWorkspace.shared.selectFile(file.urlValue.path, inFileViewerRootedAtPath: "")
        }
        
        @objc private func menuRename() {
            // TODO: implement inline rename
        }
        
        @objc private func menuTrash() {
            guard let file = clickedFile else { return }
            do {
                try FileManager.default.trashItem(at: file.urlValue, resultingItemURL: nil)
            } catch {
                log.error("[NSFileTableView] trash failed: \(error)")
            }
        }
        
        @objc private func menuGetInfo() {
            guard let file = clickedFile else { return }
            NSWorkspace.shared.activateFileViewerSelecting([file.urlValue])
        }
        
        @objc private func menuOpenOnOtherPanel() {
            // TODO: implement via AppState
        }
        
        @objc private func menuAddToFavorites() {
            guard let file = clickedFile else { return }
            UserFavoritesStore.shared.add(path: file.pathStr)
        }
        
        @objc private func menuNewFolder() {
            // TODO: implement new folder dialog
        }
        
        @objc private func menuRefresh() {
            // TODO: trigger refresh via AppState
        }
    }
}

// MARK: - Row View
class FileTableRowView: NSTableRowView {
    var isFocused = false
    var colorStore: ColorThemeStore?
    var rowIndex = 0
    
    override func drawBackground(in dirtyRect: NSRect) {
        let theme = colorStore?.activeTheme ?? ColorTheme.defaultTheme
        let base = isFocused ? NSColor(theme.warmWhite) : NSColor.controlBackgroundColor
        let stripe = base.blended(withFraction: 0.03, of: .black) ?? base
        ((rowIndex % 2 == 0) ? base : stripe).setFill()
        bounds.fill()
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let theme = colorStore?.activeTheme ?? ColorTheme.defaultTheme
        let color = isFocused ? NSColor(theme.selectionActive) : NSColor(theme.selectionInactive)
        color.setFill()
        let borderColor = isFocused ? NSColor(theme.selectionBorder) : NSColor(theme.selectionInactive).withAlphaComponent(0.3)
        let rect = bounds.insetBy(dx: 4, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        path.fill()
        borderColor.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
    
    override var isEmphasized: Bool {
        get { isFocused }
        set {}
    }
    
    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        isSelected && isFocused ? .emphasized : .normal
    }
}
