// NSResizableDividerView.swift
// MiMiNavigator — AppKit view for column resize drag.
// Uses NSEvent.deltaX directly, immune to SwiftUI layout cycles.

import AppKit

final class NSResizableDividerView: NSView {

    // MARK: - Callbacks

    var onDrag: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    // MARK: - State

    private var isDragging = false

    // MARK: - NSView

    override var acceptsFirstResponder: Bool { true }

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
            ))
    }

    override func draw(_ dirtyRect: NSRect) {
        drawDividerLine()
    }

    private func drawDividerLine() {
        let x = (bounds.width / 2).rounded() - 0.5
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: bounds.minY))
        path.line(to: NSPoint(x: x, y: bounds.maxY))
        path.lineWidth = isDragging ? 2.0 : 1.0
        (isDragging ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        onDrag?(event.deltaX)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        needsDisplay = true
        onDragEnd?()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }
}
