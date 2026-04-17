// PathAutoCompletePopupController.swift
// MiMiNavigator
//
// Created by Codex on 17.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import AppKit

struct AutoCompleteItem {
    let name: String
    let isDirectory: Bool
    let matchPrefix: String
}

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

        if panel == nil {
            createPanel()
        }

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

            panel.contentView?.wantsLayer = true
            guard let layer = panel.contentView?.layer else { return }

            layer.transform = CATransform3DMakeScale(0.92, 0.92, 1)

            let spring = CASpringAnimation(keyPath: "transform.scale")
            spring.fromValue = 0.92
            spring.toValue = 1.0
            spring.damping = 14
            spring.stiffness = 180
            spring.mass = 1
            spring.initialVelocity = 0
            spring.duration = spring.settlingDuration
            layer.add(spring, forKey: "springScale")

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true

                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = 1
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.22)
                layer.transform = CATransform3DIdentity
                CATransaction.commit()
            }

            installMonitors(for: panel)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
        }
    }

    func hide() {
        monitors.remove()
        guard let panel, panel.isVisible else {
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
            { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                context.allowsImplicitAnimation = true
                panel.animator().alphaValue = 0
                panel.animator().setFrame(shrunkFrame, display: true)
            },
            completionHandler: {
                Task { @MainActor in
                    parentWindow?.removeChildWindow(panel)
                    panel.orderOut(nil)
                }
            }
        )

        items = []
    }

    func selectRow(_ index: Int) {
        guard let tableView, index >= 0, index < items.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    private func installMonitors(for panel: NSPanel) {
        monitors.install(
            panel: panel,
            onHide: { [weak self] in self?.hide() },
            onClickOutside: { [weak self] in self?.onDismissedByClickOutside?() },
            shouldDismissOnClick: { [weak self] _ in
                guard let self else { return true }
                if let rect = self.anchorScreenRect(), rect.contains(NSEvent.mouseLocation) {
                    return false
                }
                return true
            },
            installResignObserver: false
        )
    }

    private func anchorScreenRect() -> NSRect? {
        guard let window = NSApp.keyWindow else { return nil }
        let windowHeight = window.frame.height
        let appKitY = windowHeight - anchorFrame.maxY
        let origin = window.convertPoint(toScreen: NSPoint(x: anchorFrame.minX, y: appKitY))
        return NSRect(x: origin.x, y: origin.y, width: anchorFrame.width, height: anchorFrame.height)
    }

    private func createPanel() {
        let panel = makePanel()
        let effectView = makeEffectView()
        panel.contentView = effectView

        let scrollView = makeScrollView()
        effectView.addSubview(scrollView)
        setupScrollConstraints(scrollView, in: effectView)

        let tableView = makeTableView()
        scrollView.documentView = tableView

        self.panel = panel
        self.tableView = tableView
    }

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

    private func makeEffectView() -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.masksToBounds = true
        return effectView
    }

    private func makeScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }

    private func setupScrollConstraints(_ scrollView: NSScrollView, in effectView: NSView) {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -6),
            scrollView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])
    }

    private func makeTableView() -> NSTableView {
        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.target = self
        tableView.doubleAction = #selector(tableDoubleClick)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.sizeLastColumnToFit()

        let delegate = AutoCompleteTableDelegate(controller: self)
        tableView.dataSource = delegate
        tableView.delegate = delegate
        objc_setAssociatedObject(tableView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

        return tableView
    }

    final class CustomSelectionRowView: NSTableRowView {
        override var isEmphasized: Bool {
            get { false }
            set {}
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
        guard let tableView else { return }
        let row = tableView.clickedRow
        if row >= 0, row < items.count {
            onSelect?(row)
        }
    }
}

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
        cell?.imageView?.image =
            NSImage(named: iconName)
            ?? NSImage(systemSymbolName: item.isDirectory ? "folder.fill" : "doc", accessibilityDescription: nil)

        let attrString = NSMutableAttributedString(
            string: item.name,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ]
        )

        if !item.matchPrefix.isEmpty,
           let range = item.name.range(of: item.matchPrefix, options: [.caseInsensitive, .anchored]) {
            let nsRange = NSRange(range, in: item.name)
            attrString.addAttribute(
                .font,
                value: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                range: nsRange
            )
        }

        cell?.textField?.attributedStringValue = attrString
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        AutoCompletePopupController.CustomSelectionRowView()
    }

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
