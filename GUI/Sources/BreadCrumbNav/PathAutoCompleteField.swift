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
    @State private var appState = AppState()
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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                popupController.anchorFrame = geo.frame(in: .global)
                            }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                popupController.anchorFrame = newFrame
                            }
                    }
                )
                .onAppear {
                    popupController.onDismissedByClickOutside = { [self] in
                        showSuggestions = false
                        suggestions = []
                        ghostSuffix = ""
                    }
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
        guard isValidAbsolutePath(path) else {
            dismissPopup()
            return
        }

        let (dirURL, prefix) = splitPathAndPrefix(path)

        guard directoryExists(dirURL) else {
            dismissPopup()
            return
        }

        do {
            let contents = try loadDirectoryContents(at: dirURL)
            let matches = buildSuggestions(from: contents, prefix: prefix)

            applySuggestions(matches, prefix: prefix)
        } catch {
            log.verbose("[PathAutoComplete] scan failed: \(error.localizedDescription)")
            dismissPopup()
        }
    }

    private func isValidAbsolutePath(_ path: String) -> Bool {
        !path.isEmpty && path.hasPrefix("/")
    }

    private func directoryExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func loadDirectoryContents(at url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
    }

    private func buildSuggestions(from contents: [URL], prefix: String) -> [String] {
        let showHidden = appState.showHiddenFilesSnapshot()

        var result =
            contents
            .filter { isDirAtURL($0) }
            .map(\.lastPathComponent)
            .filter { name in
                if !showHidden && name.hasPrefix(".") { return false }
                return prefix.isEmpty || name.lowercased().hasPrefix(prefix.lowercased())
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if result.count > maxSuggestions {
            result = Array(result.prefix(maxSuggestions))
        }

        return result
    }

    private func applySuggestions(_ matches: [String], prefix: String) {
        suggestions = matches
        selectedIndex = 0
        showSuggestions = !matches.isEmpty

        updateGhostFromSelection()

        if showSuggestions {
            let items = matches.map {
                AutoCompleteItem(name: $0, isDirectory: true, matchPrefix: prefix)
            }

            popupController.show(items: items, selectedIndex: 0) { idx in
                if idx >= 0, idx < suggestions.count {
                    applySuggestion(suggestions[idx])
                }
            }
        } else {
            popupController.hide()
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
        else {
            ghostSuffix = ""
            return
        }
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
/// Dismisses on click outside, ESC key, or app deactivation.
@MainActor
final class AutoCompletePopupController {
    private var panel: NSPanel?
    private var tableView: NSTableView?
    private(set) var items: [AutoCompleteItem] = []
    var onSelect: ((Int) -> Void)?
    var anchorFrame: CGRect = .zero
    private var monitors = PopupEventMonitors()
    var onDismissedByClickOutside: (() -> Void)?

    private let rowHeight: CGFloat = 32
    private let maxVisibleRows = 12
    private let minPanelHeight: CGFloat = 72
    private let panelPadding: CGFloat = 12

    // MARK: - Show
    func show(items: [AutoCompleteItem], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        self.items = items
        self.onSelect = onSelect
        guard !items.isEmpty else {
            hide()
            return
        }
        let visibleRows = min(items.count, maxVisibleRows)
        let panelHeight = max(CGFloat(visibleRows) * rowHeight + panelPadding, minPanelHeight)
        let panelWidth = max(anchorFrame.width, 300)
        if panel == nil { createPanel() }
        guard let panel, let window = NSApp.keyWindow else { return }
        let windowHeight = window.frame.height
        let appKitX = anchorFrame.minX
        let appKitY = windowHeight - anchorFrame.maxY
        let pointInScreen = window.convertPoint(toScreen: NSPoint(x: appKitX, y: appKitY))
        let targetFrame = NSRect(
            x: pointInScreen.x,
            y: pointInScreen.y - panelHeight - 2,
            width: panelWidth,
            height: panelHeight
        )
        tableView?.reloadData()
        selectRow(selectedIndex)
        if !panel.isVisible {
            let startFrame = NSRect(
                x: targetFrame.origin.x,
                y: targetFrame.origin.y + 8,
                width: targetFrame.width,
                height: targetFrame.height
            )

            panel.setFrame(startFrame, display: false)
            panel.alphaValue = 0

            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)

            // Enable layer for spring animation
            panel.contentView?.wantsLayer = true
            guard let layer = panel.contentView?.layer else { return }

            // Initial scale (slightly smaller)
            layer.transform = CATransform3DMakeScale(0.92, 0.92, 1)

            // Spring animation (scale)
            let spring = CASpringAnimation(keyPath: "transform.scale")
            spring.fromValue = 0.92
            spring.toValue = 1.0
            spring.damping = 14
            spring.stiffness = 180
            spring.mass = 1
            spring.initialVelocity = 0
            spring.duration = spring.settlingDuration

            layer.add(spring, forKey: "springScale")

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true

                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = 1
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.22)
                layer.transform = CATransform3DIdentity
                CATransaction.commit()
            }

            installMonitors(for: panel)
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
        }
    }

    // MARK: - Hide
    func hide() {
        monitors.remove()
        guard let panel = self.panel, panel.isVisible else {
            items = []
            return
        }
        let parentWindow = panel.parent
        let shrunkFrame = NSRect(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y + 6,
            width: panel.frame.width,
            height: panel.frame.height
        )
        panel.contentView?.wantsLayer = true
        let layer = panel.contentView?.layer

        let springOut = CASpringAnimation(keyPath: "transform.scale")
        springOut.fromValue = 1.0
        springOut.toValue = 0.96
        springOut.damping = 16
        springOut.stiffness = 160
        springOut.mass = 1
        springOut.duration = springOut.settlingDuration

        layer?.add(springOut, forKey: "springOut")

        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.14
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                ctx.allowsImplicitAnimation = true
                panel.animator().alphaValue = 0
                panel.animator().setFrame(shrunkFrame, display: true)
            },
            completionHandler: {
                Task { @MainActor in
                    parentWindow?.removeChildWindow(panel)
                    panel.orderOut(nil)
                }
            })
        items = []
    }

    // MARK: - Select Row
    func selectRow(_ index: Int) {
        guard let tv = tableView, index >= 0, index < items.count else { return }
        tv.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tv.scrollRowToVisible(index)
    }

    // MARK: - Monitors via PopupEventMonitors
    private func installMonitors(for panel: NSPanel) {
        monitors.install(
            panel: panel,
            onHide: { [weak self] in self?.hide() },
            onClickOutside: { [weak self] in self?.onDismissedByClickOutside?() },
            shouldDismissOnClick: { [weak self] _ in
                // keep popup open when click lands inside the text field anchor rect
                guard let self else { return true }
                if let rect = self.anchorScreenRect(),
                    rect.contains(NSEvent.mouseLocation)
                {
                    return false
                }
                return true
            },
            installResignObserver: false  // autocomplete closes on hide(), not app resign
        )
    }

    // MARK: - Anchor Screen Rect
    private func anchorScreenRect() -> NSRect? {
        guard let window = NSApp.keyWindow else { return nil }
        let windowHeight = window.frame.height
        let appKitY = windowHeight - anchorFrame.maxY
        let origin = window.convertPoint(toScreen: NSPoint(x: anchorFrame.minX, y: appKitY))
        return NSRect(x: origin.x, y: origin.y, width: anchorFrame.width, height: anchorFrame.height)
    }

    // MARK: - Create Panel
    private func createPanel() {
        let p = makePanel()
        let effect = makeEffectView()
        p.contentView = effect

        let scrollView = makeScrollView()
        effect.addSubview(scrollView)
        setupScrollConstraints(scrollView, in: effect)

        let tableView = makeTableView()
        scrollView.documentView = tableView

        self.panel = p
        self.tableView = tableView
    }

    // MARK: - Panel Factory
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.hasShadow = true
        panel.backgroundColor = .controlBackgroundColor
        panel.isOpaque = false
        panel.level = .floating
        return panel
    }

    // MARK: - Effect View
    private func makeEffectView() -> NSVisualEffectView {
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true
        return effect
    }

    // MARK: - ScrollView
    private func makeScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }

    // MARK: - Constraints
    private func setupScrollConstraints(_ scrollView: NSScrollView, in effect: NSView) {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: effect.topAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -6),
            scrollView.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
        ])
    }

    // MARK: - TableView
    private func makeTableView() -> NSTableView {
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

        return tv
    }

    // MARK: - Custom Selection Row View
    final class CustomSelectionRowView: NSTableRowView {
        override var isEmphasized: Bool {
            get { false }
            set { }
        }

        override func drawSelection(in dirtyRect: NSRect) {
            let rect = bounds.insetBy(dx: 2, dy: 2)
            let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

            NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.72, alpha: 0.55).setFill()
            path.fill()

            NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.44, alpha: 0.95).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    @objc private func tableDoubleClick() {
        guard let tv = tableView else { return }
        let row = tv.clickedRow
        if row >= 0, row < items.count {
            onSelect?(row)
        }
    }

    // deinit handled by PopupEventMonitors.deinit — no manual cleanup needed
}

// MARK: - Auto Complete Table Delegate
@MainActor
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
            cell = makeCell(identifier: cellID)
        }
        let iconName = item.isDirectory ? NSImage.folderName : NSImage.Name("NSDocument")
        cell!.imageView?.image =
            NSImage(named: iconName)
            ?? NSImage(systemSymbolName: item.isDirectory ? "folder.fill" : "doc", accessibilityDescription: nil)
        let attrStr = NSMutableAttributedString(
            string: item.name,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
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

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        AutoCompletePopupController.CustomSelectionRowView()
    }

    // MARK: - Cell Factory
    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        cell.addSubview(imageView)
        cell.imageView = imageView

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        textField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        cell.addSubview(textField)
        cell.textField = textField

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}
