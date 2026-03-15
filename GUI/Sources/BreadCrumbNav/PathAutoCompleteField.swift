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
                let showHidden = UserPreferences.shared.snapshot.showHiddenFiles
                var matches = contents
                    .filter { url in
                        // Only directories — this is a path navigator, not a file picker
                        isDirAtURL(url)
                    }
                    .map(\.lastPathComponent)
                    .filter { name in
                        // Respect global "show hidden files" toggle
                        if !showHidden && name.hasPrefix(".") { return false }
                        return prefix.isEmpty || name.lowercased().hasPrefix(prefix.lowercased())
                    }
                    .sorted { lhs, rhs in
                        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                    }
                if matches.count > maxSuggestions {
                    matches = Array(matches.prefix(maxSuggestions))
                }
                suggestions = matches
                selectedIndex = 0
                showSuggestions = !matches.isEmpty
                updateGhostFromSelection()
                if showSuggestions {
                    let items = matches.map { name in
                        AutoCompleteItem(name: name, isDirectory: true, matchPrefix: prefix)
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
    /// Dismisses on click outside, ESC key, or app deactivation.
    @MainActor
    final class AutoCompletePopupController: @unchecked Sendable {
        private var panel: NSPanel?
        private var tableView: NSTableView?
        private(set) var items: [AutoCompleteItem] = []
        var onSelect: ((Int) -> Void)?
        var anchorFrame: CGRect = .zero
        private var clickOutsideMonitor: Any?
        private var escKeyMonitor: Any?
        var onDismissedByClickOutside: (() -> Void)?

        private let rowHeight: CGFloat = 28
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
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.18
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    ctx.allowsImplicitAnimation = true
                    panel.animator().setFrame(targetFrame, display: true)
                    panel.animator().alphaValue = 1
                }
                installMonitors()
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
            removeMonitors()
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
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                ctx.allowsImplicitAnimation = true
                panel.animator().alphaValue = 0
                panel.animator().setFrame(shrunkFrame, display: true)
            }, completionHandler: {
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

        // MARK: - Click Outside & ESC Monitors
        private func installMonitors() {
            removeMonitors()
            clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self, let panel = self.panel, panel.isVisible else { return event }
                let clickWindow = event.window
                if clickWindow === panel { return event }
                let textFieldScreenRect = self.anchorScreenRect()
                if let textFieldScreenRect, textFieldScreenRect.contains(NSEvent.mouseLocation) {
                    return event
                }
                self.hide()
                self.onDismissedByClickOutside?()
                return event
            }
            escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let panel = self.panel, panel.isVisible else { return event }
                if event.keyCode == 53 {
                    self.hide()
                    self.onDismissedByClickOutside?()
                    return nil
                }
                return event
            }
        }

        // MARK: - Remove Monitors
        private func removeMonitors() {
            if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
            if let m = escKeyMonitor { NSEvent.removeMonitor(m); escKeyMonitor = nil }
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
            let effect = NSVisualEffectView()
            effect.material = .popover
            effect.state = .active
            effect.blendingMode = .behindWindow
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 8
            effect.layer?.masksToBounds = true
            p.contentView = effect
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.drawsBackground = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: effect.topAnchor, constant: 4),
                scrollView.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -4),
                scrollView.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            ])
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

        deinit {
            removeMonitors()
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
