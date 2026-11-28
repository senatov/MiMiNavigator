// NSResizableDividerView.swift
// MiMiNavigator — AppKit view for column resize drag.
// Uses window coordinates so moving the divider does not change the drag origin.

import AppKit

// MARK: - NS Resizable Divider View

final class NSResizableDividerView: NSView {
    // MARK: - Callbacks

    var onDragStart: (() -> Void)?
    var onDrag: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var dividerColor: NSColor = .separatorColor {
        didSet { needsDisplay = true }
    }

    // MARK: - State

    private var dragOriginX: CGFloat?
    private var cursorPushed = false

    // MARK: - NSView

    override var acceptsFirstResponder: Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func draw(_: NSRect) {
        drawDividerLine()
    }

    private func drawDividerLine() {
        guard dragOriginX != nil else { return }
        let x = (bounds.width / 2).rounded() - 0.5
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: bounds.minY))
        path.line(to: NSPoint(x: x, y: bounds.maxY))
        path.lineWidth = 2.0
        NSColor.controlAccentColor.setStroke()
        path.stroke()
    }

    // MARK: - Mouse Events

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        dragOriginX = event.locationInWindow.x
        onDragStart?()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOriginX else { return }
        onDrag?(event.locationInWindow.x - dragOriginX)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard dragOriginX != nil else { return }
        dragOriginX = nil
        needsDisplay = true
        onDragEnd?()
        // Reset cursor if mouse ended outside our bounds
        let loc = convert(event.locationInWindow, from: nil)
        if !bounds.contains(loc), cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
    }

    override func mouseEntered(with _: NSEvent) {
        guard !cursorPushed else { return }
        NSCursor.resizeLeftRight.push()
        cursorPushed = true
    }

    override func mouseExited(with _: NSEvent) {
        guard cursorPushed else { return }
        NSCursor.pop()
        cursorPushed = false
    }
}
