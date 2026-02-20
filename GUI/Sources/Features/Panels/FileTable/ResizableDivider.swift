// ResizableDivider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Refactored: 20.02.2026 — NSViewRepresentable for stable cursor + reliable 20pt hit area
// Copyright © 2026 Senatov. All rights reserved.
//
// Why NSViewRepresentable:
//   SwiftUI onHover + NSCursor.push/pop is unreliable — cursor flickers because onHover
//   fires on every mouse-moved event and loses tracking when mouse moves 1px outside.
//   NSView.resetCursorRects is the macOS-native way: cursor stays locked during drag.
//
// Layout: visual line = 1pt (same as ColumnSeparator).
//         layout footprint = 1pt (NSView intrinsicContentSize.width = 1).
//         hit area = 20pt cursor rect centered on the line — does NOT affect layout.

import AppKit
import SwiftUI

// MARK: - ResizableDivider (SwiftUI wrapper)
struct ResizableDivider: View {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    let onEnd: () -> Void
    var onAutoFit: (() -> CGFloat)? = nil

    var body: some View {
        _ResizableDividerNSView(
            width: $width,
            minWidth: min,
            maxWidth: max,
            onEnd: onEnd,
            onAutoFit: onAutoFit
        )
        // Layout footprint: 1pt wide, full height of parent
        .frame(width: ColumnSeparatorStyle.width)
    }
}

// MARK: - NSViewRepresentable bridge
private struct _ResizableDividerNSView: NSViewRepresentable {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let onEnd: () -> Void
    var onAutoFit: (() -> CGFloat)?

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $width, minWidth: minWidth, maxWidth: maxWidth,
                    onEnd: onEnd, onAutoFit: onAutoFit)
    }

    func makeNSView(context: Context) -> DividerNSView {
        let v = DividerNSView(coordinator: context.coordinator)
        context.coordinator.view = v
        return v
    }

    func updateNSView(_ nsView: DividerNSView, context: Context) {
        context.coordinator.minWidth = minWidth
        context.coordinator.maxWidth = maxWidth
        context.coordinator.onEnd = onEnd
        context.coordinator.onAutoFit = onAutoFit
        nsView.needsDisplay = true
    }
}

// MARK: - Coordinator (drag state)
private final class Coordinator {
    var binding: Binding<CGFloat>
    var minWidth: CGFloat
    var maxWidth: CGFloat
    var onEnd: () -> Void
    var onAutoFit: (() -> CGFloat)?
    weak var view: DividerNSView?

    // Drag state
    var isDragging = false
    var dragStartWidth: CGFloat = 0
    var dragStartX: CGFloat = 0
    var lastClickTime: TimeInterval = 0

    init(binding: Binding<CGFloat>, minWidth: CGFloat, maxWidth: CGFloat,
         onEnd: @escaping () -> Void, onAutoFit: (() -> CGFloat)?) {
        self.binding = binding
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.onEnd = onEnd
        self.onAutoFit = onAutoFit
    }
}

// MARK: - DividerNSView
final class DividerNSView: NSView {
    private let coordinator: Coordinator
    /// Hit area width in points — 20pt is easy to grab
    private let hitWidth: CGFloat = 20

    fileprivate init(coordinator: Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        // Accept mouse events
        self.acceptsTouchEvents = false
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - Layout: intrinsic width = 1pt (visual line only)
    override var intrinsicContentSize: NSSize {
        NSSize(width: ColumnSeparatorStyle.width, height: NSView.noIntrinsicMetric)
    }

    // MARK: - Cursor rect: 20pt centered, covers the 1pt line comfortably
    override func resetCursorRects() {
        let cursorRect = NSRect(
            x: bounds.midX - hitWidth / 2,
            y: bounds.minY,
            width: hitWidth,
            height: bounds.height
        )
        addCursorRect(cursorRect, cursor: .resizeLeftRight)
    }

    // MARK: - Hit test: respond to 20pt around center
    override func hitTest(_ point: NSPoint) -> NSView? {
        let expanded = NSRect(
            x: bounds.midX - hitWidth / 2,
            y: bounds.minY,
            width: hitWidth,
            height: bounds.height
        )
        return expanded.contains(point) ? self : nil
    }

    // MARK: - Draw: 1pt vertical line
    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor
        if coordinator.isDragging {
            color = NSColor(ColumnSeparatorStyle.dragColor)
        } else {
            // Check if mouse is hovering (window knows mouse location)
            let mouseInView = convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
            let isHovering = hitTest(mouseInView) != nil
            color = isHovering
                ? NSColor(ColumnSeparatorStyle.hoverColor)
                : NSColor(ColumnSeparatorStyle.color)
        }
        color.setFill()
        NSRect(x: bounds.midX - ColumnSeparatorStyle.width / 2,
               y: bounds.minY,
               width: ColumnSeparatorStyle.width,
               height: bounds.height).fill()
    }

    // MARK: - Mouse events
    override func mouseDown(with event: NSEvent) {
        let now = event.timestamp
        let loc = convert(event.locationInWindow, from: nil)

        // Double-click: auto-fit
        if event.clickCount == 2, let autoFit = coordinator.onAutoFit {
            let optimal = max(coordinator.minWidth, min(autoFit(), coordinator.maxWidth))
            coordinator.binding.wrappedValue = optimal
            coordinator.onEnd()
            log.debug("[ResizableDivider] auto-fit width=\(optimal)")
            return
        }

        // Start drag
        coordinator.isDragging = true
        coordinator.dragStartWidth = coordinator.binding.wrappedValue
        coordinator.dragStartX = event.locationInWindow.x +
            (window?.frame.origin.x ?? 0)
        coordinator.lastClickTime = now
        needsDisplay = true

        // Lock cursor during drag
        NSCursor.resizeLeftRight.set()
        window?.disableCursorRects()
    }

    override func mouseDragged(with event: NSEvent) {
        guard coordinator.isDragging else { return }

        let globalX = event.locationInWindow.x + (window?.frame.origin.x ?? 0)
        let delta = globalX - coordinator.dragStartX
        let newWidth = coordinator.dragStartWidth + delta
        coordinator.binding.wrappedValue = max(coordinator.minWidth,
                                                min(newWidth, coordinator.maxWidth))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard coordinator.isDragging else { return }
        coordinator.isDragging = false
        coordinator.onEnd()
        log.debug("[ResizableDivider] drag ended width=\(coordinator.binding.wrappedValue)")

        // Restore cursor rects
        window?.enableCursorRects()
        window?.resetCursorRects()
        needsDisplay = true
    }

    // Redraw on mouse-moved to update hover color
    override func mouseMoved(with event: NSEvent) {
        needsDisplay = true
    }

    override var acceptsFirstResponder: Bool { true }
}
