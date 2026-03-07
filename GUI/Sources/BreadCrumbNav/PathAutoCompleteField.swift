// PathAutoCompleteField.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Text field with directory autocomplete — NSPanel-based dropdown + inline ghost completion.

import AppKit
import SwiftUI

// MARK: - Path Auto Complete Field
/// Text field with directory path autocomplete.
/// Features: NSPanel-based floating dropdown (escapes parent clipping), inline ghost text,
/// Tab/RightArrow to accept, arrow keys to navigate, Escape to dismiss.
struct PathAutoCompleteField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var suggestions: [String] = []
    @State private var showSuggestions = false
    @State private var selectedIndex: Int = 0
    @State private var ghostSuffix: String = ""
    @State private var suppressOnChange = false
    @State private var popupController = AutoCompletePopupController()

    private let maxSuggestions = 12

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .leading) {
            if !ghostSuffix.isEmpty {
                Text(text + ghostSuffix)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.gray.opacity(0.45))
                    .lineLimit(1)
                    .padding(.leading, 7)
                    .allowsHitTesting(false)
            }
            TextField(L10n.PathInput.placeholder, text: $text)
                .font(.system(size: 13, design: .monospaced))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textContentType(.none)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(.rect(cornerRadius: 6))
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    guard !suppressOnChange else { return }
                    updateSuggestions(for: newValue)
                }
                .onSubmit {
                    dismissPopup()
                    onSubmit()
                }
                .onExitCommand {
                    if showSuggestions {
                        dismissPopup()
                    } else {
                        onCancel()
                    }
                }
                .onKeyPress(.downArrow) {
                    if showSuggestions, !suggestions.isEmpty {
                        selectedIndex = min(selectedIndex + 1, suggestions.count - 1)
                        updateGhostFromSelection()
                        popupController.selectRow(selectedIndex)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if showSuggestions, !suggestions.isEmpty {
                        selectedIndex = max(selectedIndex - 1, 0)
                        updateGhostFromSelection()
                        popupController.selectRow(selectedIndex)
                    }
                    return .handled
                }
                .onKeyPress(.tab) {
                    acceptCompletion()
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    if !ghostSuffix.isEmpty {
                        acceptCompletion()
                        return .handled
                    }
                    return .ignored
                }
                .background(GeometryReader { geo in
                    Color.clear.onAppear {
                        popupController.anchorFrame = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        popupController.anchorFrame = newFrame
                    }
                })
                .onAppear {
                    DispatchQueue.main.async {
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                            editor.selectAll(nil)
                        }
                    }
                }
                .onDisappear {
                    popupController.hide()
                }
        }
    }

    // MARK: - Update Suggestions
    private func updateSuggestions(for path: String) {
        guard !path.isEmpty, path.hasPrefix("/") else {
            dismissPopup()
            return
        }
        let (dirURL, prefix) = splitPathAndPrefix(path)
        let fm = FileManager.default
        guard fm.fileExists(atPath: dirURL.path) else {
            dismissPopup()
            return
        }
        do {
            let contents = try fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
            var matches = contents
                .map(\.lastPathComponent)
                .filter { name in
                    prefix.isEmpty || name.lowercased().hasPrefix(prefix.lowercased())
                }
                .sorted { lhs, rhs in
                    let lDir = isDirAtURL(dirURL.appendingPathComponent(lhs))
                    let rDir = isDirAtURL(dirURL.appendingPathComponent(rhs))
                    if lDir != rDir { return lDir }
                    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                }
            if matches.count > maxSuggestions {
                matches = Array(matches.prefix(maxSuggestions))
            }
            suggestions = matches
            selectedIndex = 0
            showSuggestions = !matches.isEmpty
            updateGhostFromSelection()
            if showSuggestions {
                let items = matches.map { name -> AutoCompleteItem in
                    let isDir = isDirAtURL(dirURL.appendingPathComponent(name))
                    return AutoCompleteItem(name: name, isDirectory: isDir, matchPrefix: prefix)
                }
                popupController.show(items: items, selectedIndex: 0) { idx in
                    if idx >= 0, idx < suggestions.count {
                        applySuggestion(suggestions[idx])
                    }
                }
            } else {
                popupController.hide()
            }
        } catch {
            log.verbose("[PathAutoComplete] scan failed: \(error.localizedDescription)")
            dismissPopup()
        }
    }

    // MARK: - Accept Completion
    private func acceptCompletion() {
        if !ghostSuffix.isEmpty {
            suppressOnChange = true
            text = text + ghostSuffix
            ghostSuffix = ""
            suppressOnChange = false
            updateSuggestions(for: text)
        } else if showSuggestions, !suggestions.isEmpty,
                  selectedIndex >= 0, selectedIndex < suggestions.count
        {
            applySuggestion(suggestions[selectedIndex])
        }
    }

    // MARK: - Apply Suggestion
    private func applySuggestion(_ name: String) {
        let (dirURL, _) = splitPathAndPrefix(text)
        let fullPath = dirURL.appendingPathComponent(name).path
        suppressOnChange = true
        if isDirAtURL(URL(fileURLWithPath: fullPath)) {
            text = fullPath + "/"
        } else {
            text = fullPath
        }
        ghostSuffix = ""
        suppressOnChange = false
        updateSuggestions(for: text)
    }

    // MARK: - Dismiss
    private func dismissPopup() {
        showSuggestions = false
        suggestions = []
        ghostSuffix = ""
        popupController.hide()
    }

    // MARK: - Ghost
    private func updateGhostFromSelection() {
        guard showSuggestions, !suggestions.isEmpty,
              selectedIndex >= 0, selectedIndex < suggestions.count
        else { ghostSuffix = ""; return }
        let selected = suggestions[selectedIndex]
        let prefix = currentPrefix()
        if prefix.isEmpty {
            ghostSuffix = selected
        } else if selected.lowercased().hasPrefix(prefix.lowercased()) {
            ghostSuffix = String(selected.dropFirst(prefix.count))
        } else {
            ghostSuffix = ""
        }
    }

    // MARK: - Helpers
    private func splitPathAndPrefix(_ path: String) -> (URL, String) {
        if path.hasSuffix("/") {
            return (URL(fileURLWithPath: path), "")
        } else {
            let url = URL(fileURLWithPath: path)
            return (url.deletingLastPathComponent(), url.lastPathComponent)
        }
    }

    private func currentPrefix() -> String { splitPathAndPrefix(text).1 }

    private func isDirAtURL(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

// MARK: - Auto Complete Item
struct AutoCompleteItem {
    let name: String
    let isDirectory: Bool
    let matchPrefix: String
}

// MARK: - Auto Complete Popup Controller
/// Manages a floating NSPanel that displays autocomplete suggestions below the text field.
/// NSPanel escapes SwiftUI layout clipping — dropdown is never cut off by parent frames.
@MainActor
final class AutoCompletePopupController: @unchecked Sendable {
    private var panel: NSPanel?
    private var tableView: NSTableView?
    private(set) var items: [AutoCompleteItem] = []
    var onSelect: ((Int) -> Void)?
    var anchorFrame: CGRect = .zero

    private let rowHeight: CGFloat = 22
    private let maxVisibleRows = 10

    // MARK: - Show
    func show(items: [AutoCompleteItem], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        self.items = items
        self.onSelect = onSelect
        guard !items.isEmpty else { hide(); return }
        let visibleRows = min(items.count, maxVisibleRows)
        let panelHeight = CGFloat(visibleRows) * rowHeight + 8
        let panelWidth = max(anchorFrame.width, 300)
        if panel == nil { createPanel() }
        guard let panel, let window = NSApp.keyWindow else { return }
        // SwiftUI .global frame: origin at top-left of window, Y grows downward.
        // AppKit window coords: origin at bottom-left, Y grows upward.
        // Convert: appKitY = windowHeight - swiftUIY
        let windowHeight = window.frame.height
        let appKitX = anchorFrame.minX
        let appKitY = windowHeight - anchorFrame.maxY  // bottom of text field in AppKit coords
        let pointInScreen = window.convertPoint(toScreen: NSPoint(x: appKitX, y: appKitY))
        let panelFrame = NSRect(
            x: pointInScreen.x,
            y: pointInScreen.y - panelHeight - 2,
            width: panelWidth,
            height: panelHeight
        )
        panel.setFrame(panelFrame, display: true)
        log.debug("[AutoComplete] panel frame=\(panelFrame) items=\(items.count) visibleRows=\(visibleRows)")
        tableView?.reloadData()
        selectRow(selectedIndex)
        if !panel.isVisible {
            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
        }
    }

    // MARK: - Hide
    func hide() {
        panel?.parent?.removeChildWindow(panel!)
        panel?.orderOut(nil)
        items = []
    }

    // MARK: - Select Row
    func selectRow(_ index: Int) {
        guard let tv = tableView, index >= 0, index < items.count else { return }
        tv.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tv.scrollRowToVisible(index)
    }

    // MARK: - Create Panel
    private func createPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.hidesOnDeactivate = true
        p.hasShadow = true
        p.backgroundColor = .controlBackgroundColor
        p.isOpaque = false
        p.level = .floating
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width, .height]
        let tv = NSTableView()
        tv.headerView = nil
        tv.rowHeight = rowHeight
        tv.backgroundColor = .clear
        tv.selectionHighlightStyle = .regular
        tv.intercellSpacing = NSSize(width: 0, height: 0)
        tv.target = self
        tv.doubleAction = #selector(tableDoubleClick)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.isEditable = false
        col.resizingMask = .autoresizingMask
        tv.addTableColumn(col)
        tv.sizeLastColumnToFit()
        let delegate = AutoCompleteTableDelegate(controller: self)
        tv.dataSource = delegate
        tv.delegate = delegate
        objc_setAssociatedObject(tv, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        scrollView.documentView = tv
        p.contentView = scrollView
        self.panel = p
        self.tableView = tv
    }

    @objc private func tableDoubleClick() {
        guard let tv = tableView else { return }
        let row = tv.clickedRow
        if row >= 0, row < items.count {
            onSelect?(row)
        }
    }
}

// MARK: - Auto Complete Table Delegate
final class AutoCompleteTableDelegate: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private unowned let controller: AutoCompletePopupController

    init(controller: AutoCompletePopupController) {
        self.controller = controller
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        controller.items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < controller.items.count else { return nil }
        let item = controller.items[row]
        let cellID = NSUserInterfaceItemIdentifier("AutoCompleteCell")
        var cell = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell!.identifier = cellID
            let iv = NSImageView()
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.imageScaling = .scaleProportionallyUpOrDown
            cell!.addSubview(iv)
            cell!.imageView = iv
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingTail
            tf.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            cell!.addSubview(tf)
            cell!.textField = tf
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 6),
                iv.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                iv.widthAnchor.constraint(equalToConstant: 16),
                iv.heightAnchor.constraint(equalToConstant: 16),
                tf.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 6),
                tf.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }
        let iconName = item.isDirectory ? NSImage.folderName : NSImage.Name("NSDocument")
        cell!.imageView?.image = NSImage(named: iconName) ?? NSImage(systemSymbolName: item.isDirectory ? "folder.fill" : "doc", accessibilityDescription: nil)
        let attrStr = NSMutableAttributedString(string: item.name, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        ])
        if !item.matchPrefix.isEmpty,
           let range = item.name.range(of: item.matchPrefix, options: [.caseInsensitive, .anchored])
        {
            let nsRange = NSRange(range, in: item.name)
            attrStr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold), range: nsRange)
        }
        cell!.textField?.attributedStringValue = attrStr
        return cell
    }
}
