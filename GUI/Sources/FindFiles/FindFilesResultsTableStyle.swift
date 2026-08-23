// FindFilesResultsTableStyle.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Applies main file-panel selection styling to Find Files results.

import AppKit
import SwiftUI

// MARK: - Find Files Results Table Style
struct FindFilesResultsTableStyle: NSViewRepresentable {
    let selectionVersion: Int
    let themeVersion: Int
    let rowHeight: CGFloat

    func makeNSView(context _: Context) -> FindFilesResultsTableProbe {
        FindFilesResultsTableProbe()
    }

    func updateNSView(_ view: FindFilesResultsTableProbe, context _: Context) {
        let theme = ColorThemeStore.shared.activeTheme
        view.activeFill = NSColor(theme.selectionActive)
        view.inactiveFill = NSColor(theme.selectionInactive)
        view.activeBorderColor = NSColor(theme.selectionBorder)
        view.inactiveBorderColor = NSColor(theme.selectionBorder).withAlphaComponent(
            NSColor(theme.selectionBorder).alphaComponent * 0.5
        )
        view.borderWidth = theme.selectionLineWidth
        view.rowHeight = rowHeight
        view.evenRowColor = NSColor(theme.zebraActiveEven)
        view.oddRowColor = NSColor(theme.zebraActiveOdd)
        view.tableBackgroundColor = NSColor(theme.warmWhite)
        view.applyWhenReady()
    }
}

// MARK: - Results Table Probe
final class FindFilesResultsTableProbe: NSView {
    var activeFill: NSColor = .clear
    var inactiveFill: NSColor = .clear
    var activeBorderColor: NSColor = .clear
    var inactiveBorderColor: NSColor = .clear
    var borderWidth: CGFloat = 1
    var rowHeight: CGFloat = 22
    var evenRowColor: NSColor = .clear
    var oddRowColor: NSColor = .clear
    var tableBackgroundColor: NSColor = .controlBackgroundColor
    private weak var observedTable: NSTableView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWhenReady()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applyWhenReady(attempts: Int = 8) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.apply(), attempts > 1 {
                self.applyWhenReady(attempts: attempts - 1)
            }
        }
    }

    private func apply() -> Bool {
        guard let tableView = matchingTableView() else { return false }
        if observedTable !== tableView {
            observe(tableView)
        }
        tableView.rowHeight = rowHeight
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = tableBackgroundColor
        tableView.enclosingScrollView?.backgroundColor = tableBackgroundColor
        if let scrollView = tableView.enclosingScrollView {
            ScrollBarSetup.applySystemStyle(to: scrollView)
        }
        tableView.tableColumns.forEach {
            $0.headerCell.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        }
        tableView.selectionHighlightStyle = .none
        updateVisibleRows(in: tableView)
        return true
    }

    private func observe(_ tableView: NSTableView) {
        NotificationCenter.default.removeObserver(self)
        observedTable = tableView
        tableView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(observedStateDidChange),
            name: NSTableView.selectionDidChangeNotification,
            object: tableView
        )
        if let clipView = tableView.enclosingScrollView?.contentView {
            center.addObserver(
                self,
                selector: #selector(observedStateDidChange),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }
        if let window = tableView.window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                center.addObserver(
                    self,
                    selector: #selector(observedStateDidChange),
                    name: name,
                    object: window
                )
            }
        }
    }

    @objc private func observedStateDidChange(_: Notification) {
        guard let observedTable else { return }
        updateVisibleRows(in: observedTable)
    }

    private func updateVisibleRows(in tableView: NSTableView) {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.location != NSNotFound else { return }
        let upperBound = min(visibleRows.location + visibleRows.length, tableView.numberOfRows)
        for row in visibleRows.location ..< upperBound {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) else { continue }
            rowView.backgroundColor = row.isMultiple(of: 2) ? evenRowColor : oddRowColor
            let background = selectionBackground(in: rowView)
            let isSelected = tableView.selectedRowIndexes.contains(row)
            let isActive = tableView.window?.isKeyWindow == true
            let displayScale = tableView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
            background.isHidden = !isSelected
            background.fillColor = isActive ? activeFill : inactiveFill
            background.borderColor = isActive ? activeBorderColor : inactiveBorderColor
            background.borderWidth = max(1 / displayScale, borderWidth)
            background.frame = rowView.bounds.insetBy(dx: 1, dy: 1)
            background.needsDisplay = true
        }
    }

    private func selectionBackground(in rowView: NSTableRowView) -> FindFilesSelectionBackgroundView {
        if let view = rowView.subviews.first(where: { $0 is FindFilesSelectionBackgroundView })
            as? FindFilesSelectionBackgroundView
        {
            return view
        }
        let view = FindFilesSelectionBackgroundView()
        view.autoresizingMask = [.width, .height]
        rowView.addSubview(view, positioned: .below, relativeTo: nil)
        return view
    }

    private func matchingTableView() -> NSTableView? {
        if let tableView = enclosingTableView(from: self) { return tableView }
        guard let contentView = window?.contentView else { return nil }
        let probeRect = convert(bounds, to: nil)
        let candidates = contentView.descendantFindResultsTableViews()
        return candidates.max {
            score(tableView: $0, probeRect: probeRect) < score(tableView: $1, probeRect: probeRect)
        }
    }

    private func score(tableView: NSTableView, probeRect: NSRect) -> CGFloat {
        let tableRect = tableView.convert(tableView.bounds, to: nil)
        let intersection = tableRect.intersection(probeRect)
        if !intersection.isNull {
            return intersection.width * intersection.height
        }
        let dx = tableRect.midX - probeRect.midX
        let dy = tableRect.midY - probeRect.midY
        return -((dx * dx) + (dy * dy))
    }

    private func enclosingTableView(from view: NSView?) -> NSTableView? {
        var current = view
        while let node = current {
            if let tableView = node as? NSTableView { return tableView }
            current = node.superview
        }
        return nil
    }
}

// MARK: - NSView Find Results Table Search

private extension NSView {
    func descendantFindResultsTableViews() -> [NSTableView] {
        var result = subviews.compactMap { $0 as? NSTableView }
        for child in subviews {
            result.append(contentsOf: child.descendantFindResultsTableViews())
        }
        return result
    }
}

// MARK: - Selection Background View
final class FindFilesSelectionBackgroundView: NSView {
    var fillColor: NSColor = .clear
    var borderColor: NSColor = .clear
    var borderWidth: CGFloat = 1

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        fillColor.setFill()
        path.fill()
        borderColor.setStroke()
        path.lineWidth = borderWidth
        path.stroke()
    }
}
