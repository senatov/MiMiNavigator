import AppKit

// MARK: - Drag Geometry
extension DragNSView {
    func panelFrameInWindowCoordinates() -> NSRect {
        guard window != nil else { return .zero }
        return convert(bounds, to: nil)
    }

    func currentMouseScreenPoint(fallback: NSPoint) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        return mouseLocation == .zero ? fallback : mouseLocation
    }

    func dropTargetProbeScreenPoint(from cursorScreenPoint: NSPoint) -> NSPoint {
        NSPoint(x: cursorScreenPoint.x, y: cursorScreenPoint.y + DragNSViewUI.dropTargetProbeYOffset)
    }

    var isPrimaryMouseDown: Bool { NSEvent.pressedMouseButtons == 1 }

    var isResizeCursor: Bool {
        let cursor = NSCursor.current
        return cursor == .resizeLeftRight || cursor == .resizeLeft || cursor == .resizeRight
    }

    func shouldHandlePrimaryDrag(_ event: NSEvent) -> Bool {
        event.type == .leftMouseDragged && isPrimaryMouseDown && !event.modifierFlags.contains(.control)
    }

    func expandedBounds(tolerance: CGFloat) -> NSRect {
        bounds.insetBy(dx: -tolerance, dy: -tolerance)
    }

    func passedDragThreshold(from start: NSPoint, to current: NSPoint) -> Bool {
        hypot(current.x - start.x, current.y - start.y) >= DragNSViewUI.dragThreshold
    }
}
