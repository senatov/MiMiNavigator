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
                evenColor: NSColor(colorStore.activeTheme.zebraActiveEven),
                oddColor: NSColor(colorStore.activeTheme.zebraActiveOdd),
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
    let evenColor: NSColor
    let oddColor: NSColor
    let version: Int
    func makeNSView(context _: Context) -> TableColumnDividerProbeView {
        let view = TableColumnDividerProbeView()
        view.color = color
        view.evenColor = evenColor
        view.oddColor = oddColor
        return view
    }

    func updateNSView(_ view: TableColumnDividerProbeView, context _: Context) {
        view.color = color
        view.evenColor = evenColor
        view.oddColor = oddColor
        view.applyWhenReady()
    }
}

// MARK: - Table Column Divider Probe View

private final class TableColumnDividerProbeView: NSView {
    var color: NSColor = .separatorColor
    var evenColor: NSColor = .controlBackgroundColor
    var oddColor: NSColor = .controlBackgroundColor
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
        guard let tableView = matchingTableView() else { return }
        tableView.gridColor = color
        tableView.gridStyleMask.insert(.solidVerticalGridLineMask)
        applyZebraBackground(to: tableView)
        applyHeaderOverlay(to: tableView)
        tableView.needsDisplay = true
        tableView.headerView?.needsDisplay = true
    }

    private func applyZebraBackground(to tableView: NSTableView) {
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .clear
        tableView.enclosingScrollView?.drawsBackground = false
        tableView.enclosingScrollView?.contentView.drawsBackground = false
        let zebra = zebraBackground(in: tableView) ?? NSTableZebraBackgroundView()
        zebra.evenColor = evenColor
        zebra.oddColor = oddColor
        zebra.rowHeight = max(tableView.rowHeight + tableView.intercellSpacing.height, 1)
        zebra.frame = tableView.bounds
        zebra.autoresizingMask = [.width, .height]
        if zebra.superview == nil {
            tableView.addSubview(zebra, positioned: .below, relativeTo: nil)
        }
        zebra.needsDisplay = true
    }

    private func zebraBackground(in tableView: NSTableView) -> NSTableZebraBackgroundView? {
        tableView.subviews.first { $0 is NSTableZebraBackgroundView } as? NSTableZebraBackgroundView
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

    private func matchingTableView() -> NSTableView? {
        if let tableView = enclosingTableView(from: self) { return tableView }
        guard let contentView = window?.contentView else { return nil }
        let probeRect = convert(bounds, to: nil)
        let candidates = contentView.descendantTableViews()
        return candidates.max { score(tableView: $0, probeRect: probeRect) < score(tableView: $1, probeRect: probeRect) }
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

// MARK: - NSTable Zebra Background View

private final class NSTableZebraBackgroundView: NSView {
    var evenColor: NSColor = .controlBackgroundColor
    var oddColor: NSColor = .controlBackgroundColor
    var rowHeight: CGFloat = 22
    override var isFlipped: Bool {
        true
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard rowHeight > 0 else { return }
        var row = Int(floor(dirtyRect.minY / rowHeight))
        var y = CGFloat(row) * rowHeight
        while y < dirtyRect.maxY {
            let color = row.isMultiple(of: 2) ? evenColor : oddColor
            color.setFill()
            NSRect(x: bounds.minX, y: y, width: bounds.width, height: rowHeight).fill()
            row += 1
            y += rowHeight
        }
    }
}

// MARK: - NSView Table Search

private extension NSView {
    func descendantTableViews() -> [NSTableView] {
        var result = subviews.compactMap { $0 as? NSTableView }
        for child in subviews {
            result.append(contentsOf: child.descendantTableViews())
        }
        return result
    }
}
