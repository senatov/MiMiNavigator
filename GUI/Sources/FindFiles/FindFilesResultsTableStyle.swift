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

    func makeNSView(context _: Context) -> FindFilesResultsTableProbe {
        FindFilesResultsTableProbe()
    }

    func updateNSView(_ view: FindFilesResultsTableProbe, context _: Context) {
        let theme = ColorThemeStore.shared.activeTheme
        view.activeFill = NSColor(theme.selectionActive)
        view.inactiveFill = NSColor(theme.selectionInactive)
        view.borderColor = NSColor(theme.selectionBorder)
        view.borderWidth = theme.selectionLineWidth
        view.applyWhenReady()
    }
}

// MARK: - Results Table Probe
final class FindFilesResultsTableProbe: NSView {
    var activeFill: NSColor = .selectedContentBackgroundColor
    var inactiveFill: NSColor = .unemphasizedSelectedContentBackgroundColor
    var borderColor: NSColor = .keyboardFocusIndicatorColor
    var borderWidth: CGFloat = 1
    private weak var observedTable: NSTableView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWhenReady()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applyWhenReady() {
        DispatchQueue.main.async { [weak self] in
            self?.apply()
        }
    }

    private func apply() {
        guard let tableView = enclosingTableView() else { return }
        if observedTable !== tableView {
            observe(tableView)
        }
        tableView.selectionHighlightStyle = .none
        updateVisibleRows(in: tableView)
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
            let background = selectionBackground(in: rowView)
            let isSelected = tableView.selectedRowIndexes.contains(row)
            background.isHidden = !isSelected
            background.fillColor = tableView.window?.isKeyWindow == true ? activeFill : inactiveFill
            background.borderColor = borderColor
            background.borderWidth = borderWidth
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

    private func enclosingTableView() -> NSTableView? {
        var current: NSView? = self
        while let node = current {
            if let tableView = node as? NSTableView { return tableView }
            current = node.superview
        }
        return nil
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
