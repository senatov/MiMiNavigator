// FileTableColumnDividerStyle.swift
// MiMiNavigator — Shared column divider styling for file tables.

import AppKit
import SwiftUI

// MARK: - File Table Column Divider Style

struct FileTableColumnDividerStyle: ViewModifier {
    @State private var colorStore = ColorThemeStore.shared
    func body(content: Content) -> some View {
        content.background(
            NSTableColumnDividerStyler(
                color: NSColor(colorStore.activeTheme.columnDividerColor),
                version: colorStore.themeVersion
            )
        )
    }
}

// MARK: - View Extension

extension View {
    func fileTableColumnDividerStyle() -> some View {
        modifier(FileTableColumnDividerStyle())
    }
}

// MARK: - NSTable Column Divider Styler

private struct NSTableColumnDividerStyler: NSViewRepresentable {
    let color: NSColor
    let version: Int
    func makeNSView(context _: Context) -> TableColumnDividerProbeView {
        let view = TableColumnDividerProbeView()
        view.color = color
        return view
    }

    func updateNSView(_ view: TableColumnDividerProbeView, context _: Context) {
        view.color = color
        view.applyWhenReady()
    }
}

// MARK: - Table Column Divider Probe View

private final class TableColumnDividerProbeView: NSView {
    var color: NSColor = .separatorColor
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWhenReady()
    }

    func applyWhenReady() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.apply()
        }
    }

    private func apply() {
        guard let tableView = enclosingTableView(from: self) else { return }
        tableView.gridColor = color
        tableView.gridStyleMask.insert(.solidVerticalGridLineMask)
        applyHeaderOverlay(to: tableView)
        tableView.needsDisplay = true
        tableView.headerView?.needsDisplay = true
    }

    private func applyHeaderOverlay(to tableView: NSTableView) {
        guard let headerView = tableView.headerView else { return }
        let overlay = headerOverlay(in: headerView) ?? TableHeaderColumnDividerOverlay()
        overlay.tableView = tableView
        overlay.color = color
        overlay.frame = headerView.bounds
        overlay.autoresizingMask = [.width, .height]
        overlay.isHidden = false
        if overlay.superview == nil {
            headerView.addSubview(overlay)
        }
        overlay.needsDisplay = true
    }

    private func headerOverlay(in headerView: NSTableHeaderView) -> TableHeaderColumnDividerOverlay? {
        headerView.subviews.first { $0 is TableHeaderColumnDividerOverlay } as? TableHeaderColumnDividerOverlay
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

// MARK: - Table Header Column Divider Overlay

private final class TableHeaderColumnDividerOverlay: NSView {
    weak var tableView: NSTableView?
    var color: NSColor = .separatorColor
    override var isFlipped: Bool {
        true
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func draw(_: NSRect) {
        guard let tableView else { return }
        color.setStroke()
        for index in 0 ..< max(tableView.numberOfColumns - 1, 0) {
            let x = tableView.rect(ofColumn: index).maxX.rounded() - 0.5
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: bounds.minY))
            path.line(to: NSPoint(x: x, y: bounds.maxY))
            path.lineWidth = 1
            path.stroke()
        }
    }
}
