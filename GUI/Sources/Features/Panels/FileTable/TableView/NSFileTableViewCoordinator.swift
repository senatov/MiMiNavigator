//
//  NSFileTableViewCoordinator.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: NSTableView Coordinator (delegate + dataSource + NSMenuDelegate).
//               Extracted from NSFileTableView.swift — handles all AppKit table callbacks.

import AppKit
import FavoritesKit
import FileModelKit
import LogKit
import SwiftUI

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
        log.debug("[Coordinator] updateFiles count=\(newFiles.count) version=\(version)")
        files = newFiles
        lastVersion = version
        rebuildIndex()
    }

    private func rebuildIndex() {
        indexByID.removeAll(keepingCapacity: true)
        for (i, f) in files.enumerated() {
            indexByID[f.id] = i
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { files.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < files.count,
            let colRaw = tableColumn?.identifier.rawValue,
            let colID = ColumnID(rawValue: colRaw)
        else { return nil }

        let file = files[row]
        let cellID = NSUserInterfaceItemIdentifier("Cell_\(colRaw)")

        var cell = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = createCell(identifier: cellID, columnID: colID)
        }

        log.debug("[Coordinator] configure cell row=\(row) col=\(colRaw)")
        configureCell(cell!, file: file, columnID: colID, row: row, tableView: tableView)
        return cell
    }

    private func createCell(identifier: NSUserInterfaceItemIdentifier, columnID: ColumnID) -> NSTableCellView {
        let cell = NSTableCellView()
        log.debug("[Coordinator] createCell id=\(identifier.rawValue)")
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
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        return cell
    }

    private func configureCell(_ cell: NSTableCellView, file: CustomFile, columnID: ColumnID, row: Int, tableView: NSTableView) {
        log.debug("[Coordinator] configureCell row=\(row) file=\(file.nameStr)")
        cell.textField?.stringValue = text(for: columnID, file: file)
        cell.textField?.font =
            columnID == .permissions
            ? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            : NSFont.systemFont(ofSize: 13)
        cell.textField?.alignment = columnID.alignment == .trailing ? .right : .left

        if columnID == .name {
            cell.imageView?.image =
                ParentDirectoryEntry.isParentEntry(file)
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
        log.debug("[Coordinator] rowViewForRow row=\(row)")
        let rv = FileTableRowView()
        rv.isFocused = isFocused
        rv.colorStore = parent.colorStore
        rv.rowIndex = row
        return rv
    }

    @objc func tableViewDoubleClick(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < files.count else {
            log.warning("[Coordinator] doubleClick invalid row=\(sender.clickedRow)")
            return
        }
        log.debug("[Coordinator] doubleClick file=\(files[row].nameStr)")
        parent.onDoubleClick(files[row])
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard row < files.count else { return nil }
        return files[row].urlValue as NSURL
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
        proposedDropOperation op: NSTableView.DropOperation
    ) -> NSDragOperation {
        if op == .on && row < files.count && files[row].isDirectory { return .move }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation)
        -> Bool
    { false }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let optionHeld = NSEvent.modifierFlags.contains(.option)

        guard let tv = tableView else { return }
        let clickedRow = tv.clickedRow

        guard clickedRow >= 0 && clickedRow < files.count else {
            // Click on empty area - panel background menu
            if optionHeld {
                addMenuItem(menu, title: "New Folder", action: #selector(menuNewFolder), key: "N")
            }
            addMenuItem(menu, title: "Refresh", action: #selector(menuRefresh), key: "r")
            menu.addItem(NSMenuItem.separator())
            addMenuItem(menu, title: "Paste", action: #selector(menuPaste), key: "v")
            if !optionHeld {
                menu.addItem(NSMenuItem.separator())
                addOptionHint(menu)
            }
            return
        }

        let file = files[clickedRow]

        // Select row if not selected
        if !tv.selectedRowIndexes.contains(clickedRow) {
            tv.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }

        if file.isDirectory {
            buildDirectoryMenu(menu, file: file, optionHeld: optionHeld)
        } else {
            buildFileMenu(menu, file: file, optionHeld: optionHeld)
        }
    }

    private func buildFileMenu(_ menu: NSMenu, file: CustomFile, optionHeld: Bool) {
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

        // SECTION 5: Rename & Delete (⌥ Option only)
        if optionHeld {
            addMenuItem(menu, title: "Rename...", action: #selector(menuRename), key: "", icon: "pencil")
            addMenuItem(menu, title: "Move to Trash", action: #selector(menuTrash), key: "", icon: "trash")
        }
        menu.addItem(NSMenuItem.separator())

        // SECTION 6: Info
        addMenuItem(menu, title: "Get Info", action: #selector(menuGetInfo), key: "i", icon: "info.circle")
        menu.addItem(NSMenuItem.separator())

        // SECTION 7: Favorites
        addMenuItem(menu, title: "Add to Favorites", action: #selector(menuAddToFavorites), key: "", icon: "star")

        if !optionHeld {
            menu.addItem(NSMenuItem.separator())
            addOptionHint(menu)
        }
    }

    private func buildDirectoryMenu(_ menu: NSMenu, file: CustomFile, optionHeld: Bool) {
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

        // SECTION 4: Rename & Delete (⌥ Option only)
        if optionHeld {
            addMenuItem(menu, title: "Rename...", action: #selector(menuRename), key: "", icon: "pencil")
            addMenuItem(menu, title: "Move to Trash", action: #selector(menuTrash), key: "", icon: "trash")
        }
        menu.addItem(NSMenuItem.separator())

        // SECTION 5: Info
        addMenuItem(menu, title: "Get Info", action: #selector(menuGetInfo), key: "i", icon: "info.circle")
        menu.addItem(NSMenuItem.separator())

        // SECTION 6: Cross-panel
        addMenuItem(
            menu, title: "Open on Other Panel", action: #selector(menuOpenOnOtherPanel), key: "", icon: "rectangle.split.2x1")
        menu.addItem(NSMenuItem.separator())

        // SECTION 7: Favorites
        addMenuItem(menu, title: "Add to Favorites", action: #selector(menuAddToFavorites), key: "", icon: "star")

        if !optionHeld {
            menu.addItem(NSMenuItem.separator())
            addOptionHint(menu)
        }
    }

    private func addMenuItem(_ menu: NSMenu, title: String, action: Selector, key: String, icon: String? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let iconName = icon, let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            item.image = img
        }
        menu.addItem(item)
    }


    private func addOptionHint(_ menu: NSMenu) {
        let hint = NSMenuItem(title: "⌥ for more…", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.systemBlue
        ]
        hint.attributedTitle = NSAttributedString(string: "⌥ for more…", attributes: attrs)
        menu.addItem(hint)
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
        let escapedPath = file.urlValue.path.replacingOccurrences(of: "'", with: "'\\''")
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
        pb.setString(file.urlValue.path, forType: .string)
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
        do {
            try fm.copyItem(at: file.urlValue, to: newURL)
            log.debug("[Coordinator] duplicated to \(newURL.path)")
        } catch {
            log.error("[Coordinator] duplicate failed: \(error)")
        }
    }

    @objc private func menuCompress() {
        guard let file = clickedFile else { return }
        log.debug("[Coordinator] compress \(file.urlValue.path)")

        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = file.urlValue.deletingLastPathComponent()
            process.arguments = ["-r", "\(file.nameStr).zip", file.nameStr]

            do {
                try process.run()
                process.waitUntilExit()
                log.debug("[Coordinator] compress finished")
            } catch {
                log.error("[Coordinator] compress failed: \(error)")
            }
        }
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
            log.error("[Coordinator] trash failed: \(error)")
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

        // Safety: Favorites should only contain directories (Finder‑like behavior)
        guard file.isDirectory else {
            log.debug("[NSFileTableView] Favorites ignored for non-directory: \(file.urlValue.path)")
            return
        }

        UserFavoritesStore.shared.add(url: file.urlValue)
    }

    @objc private func menuNewFolder() {
        // TODO: implement new folder dialog
    }

    @objc private func menuRefresh() {
        // TODO: trigger refresh via AppState
    }
}
