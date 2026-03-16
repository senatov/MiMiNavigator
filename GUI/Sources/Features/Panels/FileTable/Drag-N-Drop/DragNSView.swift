// DragOverlayView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppKit drag source overlay — initiates NSDraggingSession for multi-file drag

import AppKit
import FileModelKit
import SwiftUI

final class DragNSView: NSView, NSDraggingSource {

    var panelSide: PanelSide!
    weak var dragDropManager: DragDropManager?
    weak var appState: AppState?

    private var mouseDownPoint: NSPoint = .zero
    private let dragThreshold: CGFloat = 5.0
    private var didStartDragging = false
    private var mouseDownOnResize = false
    private var mouseMonitor: Any?
    private var dragMonitor: Any?

    /// Do not intercept normal mouse events — let SwiftUI handle clicks, selection, context menu.
    /// Drag is initiated via NSEvent local monitor instead.
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitors()
        } else {
            removeMonitors()
        }
    }

    private func installMonitors() {
        removeMonitors()

        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleMouseDown(event)
            return event  // pass through
        }

        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            if let self, self.handleMouseDragged(event) {
                return nil  // consumed by drag
            }
            return event  // pass through
        }
    }

    private func removeMonitors() {
        if let m = mouseMonitor {
            NSEvent.removeMonitor(m)
            mouseMonitor = nil
        }
        if let m = dragMonitor {
            NSEvent.removeMonitor(m)
            dragMonitor = nil
        }
    }

    // Monitor cleanup is handled by viewDidMoveToWindow(nil) → removeMonitors().
    // No deinit needed — avoids non-Sendable access from nonisolated context.

    private func handleMouseDown(_ event: NSEvent) {
        // Only track if the click is inside our bounds
        guard let window = self.window, event.window === window else { return }
        // Only react to primary (left) mouse button without control-click
        guard event.type == .leftMouseDown,
            NSEvent.pressedMouseButtons == 1,
            !event.modifierFlags.contains(.control)
        else { return }
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.contains(loc) else { return }
        mouseDownPoint = loc
        didStartDragging = false
        // Remember if cursor was resize at mouseDown — column divider drag in progress
        mouseDownOnResize =
            (NSCursor.current == NSCursor.resizeLeftRight
                || NSCursor.current == NSCursor.resizeLeft
                || NSCursor.current == NSCursor.resizeRight)
    }

    /// Returns true if drag was initiated (event consumed)
    private func handleMouseDragged(_ event: NSEvent) -> Bool {
        guard shouldHandlePrimaryDrag(event) else { return false }
        guard !didStartDragging else { return false }
        guard let appState, let panelSide else { return false }
        guard let window = self.window, event.window === window else { return false }
        guard !mouseDownOnResize else { return false }

        let currentPoint = convert(event.locationInWindow, from: nil)
        guard bounds.contains(currentPoint) else { return false }
        guard passedDragThreshold(currentPoint: currentPoint) else { return false }

        let selectedURLs = DragSelectionResolver.resolve(from: appState, side: panelSide)
        guard !selectedURLs.isEmpty else {
            log.debug("[DragOverlay] drag ignored: no selection")
            return false
        }

        startDrag(with: selectedURLs, event: event)
        return true
    }

    // MARK: - Drag Helpers

    private func shouldHandlePrimaryDrag(_ event: NSEvent) -> Bool {
        event.type == .leftMouseDragged && NSEvent.pressedMouseButtons == 1 && !event.modifierFlags.contains(.control)
    }

    private func passedDragThreshold(currentPoint: NSPoint) -> Bool {
        let deltaX = currentPoint.x - mouseDownPoint.x
        let deltaY = currentPoint.y - mouseDownPoint.y
        let distance = hypot(deltaX, deltaY)
        return distance >= dragThreshold
    }

    private func startDrag(with urls: [URL], event: NSEvent) {
        didStartDragging = true
        log.debug("[DragOverlay] starting AppKit drag with \(urls.count) file(s)")

        let draggingItems = DragSessionBuilder.makeDraggingItems(from: urls)

        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
            case .outsideApplication:
                return [.copy, .move]
            case .withinApplication:
                return [.move]
            @unknown default:
                return [.copy]
        }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        didStartDragging = false
        log.debug("[DragOverlay] drag ended operation=\(String(describing: operation.rawValue))")
    }
}
