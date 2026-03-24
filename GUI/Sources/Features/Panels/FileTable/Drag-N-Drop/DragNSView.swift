// DragOverlayView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppKit drag source overlay — initiates NSDraggingSession for multi-file drag

import AppKit
import FileModelKit
import SwiftUI

@MainActor
final class DragNSView: NSView, NSDraggingSource {

    var panelSide: PanelSide?
    weak var dragDropManager: DragDropManager?
    unowned var appState: AppState

    private var dragState = DragState(startPoint: nil, didStart: false, isResize: false)
    private var cachedSelection: [URL] = []
    private var mouseMonitor: Any?
    private var dragMonitor: Any?

    private enum UI {
        static let dragThreshold: CGFloat = 5.0
        static let dragStartTolerance: CGFloat = 10.0
    }

    init(appState: AppState) {
        self.appState = appState
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Do not intercept normal mouse events — let SwiftUI handle clicks, selection, context menu.
    /// Drag is initiated via NSEvent local monitor instead.
    /// This view intentionally returns nil to allow event passthrough.
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

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            removeMonitors()
        }
    }

    private func installMonitors() {
        removeMonitors()

        let downMask: NSEvent.EventTypeMask = [.leftMouseDown]
        let dragMask: NSEvent.EventTypeMask = [.leftMouseDragged]

        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: downMask) { [weak self] event in
            self?.handleMouseDown(event)
            return event  // pass through
        }

        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: dragMask) { [weak self] event in
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
        guard let window = self.window, event.window === window else { return }
        guard event.type == .leftMouseDown, isPrimaryMouseDown, !event.modifierFlags.contains(.control) else { return }
        let locWindow = event.locationInWindow
        let loc = convert(locWindow, from: nil)
        guard bounds.contains(loc) else { return }
        dragState.startPoint = locWindow
        dragState.didStart = false
        dragState.isResize = isResizeCursor
        if let panelSide {
            cachedSelection = DragSelectionResolver.resolve(from: appState, side: panelSide)
        } else {
            cachedSelection = []
        }
    }

    /// Returns true if drag was initiated (event consumed)
    private func handleMouseDragged(_ event: NSEvent) -> Bool {
        guard let window = self.window, event.window === window else {
            //log.debug("[DragOverlay] ignored: event window mismatch or no window")
            return false
        }
        guard shouldHandlePrimaryDrag(event) else {
            // Removed noisy debug log
            return false
        }
        guard !dragState.didStart, !dragState.isResize else {
            // Removed noisy debug log
            return false
        }
        guard let mouseDownPoint = dragState.startPoint else {
            // Removed noisy debug log
            return false
        }
        guard resolvedDependencies() != nil else { return false }

        let currentWindowPoint = event.locationInWindow
        let currentPoint = convert(currentWindowPoint, from: nil)
        guard expandedBounds(tolerance: UI.dragStartTolerance).contains(currentPoint) else {
            // Removed noisy debug log
            return false
        }
        guard passedDragThreshold(from: mouseDownPoint, to: currentWindowPoint) else {
            // Removed noisy debug log
            return false
        }

        let selectedURLs = cachedSelection
        guard !selectedURLs.isEmpty else {
            // no selection, ignore silently
            return false
        }

        beginDrag(with: selectedURLs, event: event)
        return true
    }

    // MARK: - Drag Helpers

    private var isPrimaryMouseDown: Bool {
        NSEvent.pressedMouseButtons == 1
    }

    private var isResizeCursor: Bool {
        // TODO: Replace with explicit resize zone detection if splitter is introduced
        let c = NSCursor.current
        return c == .resizeLeftRight || c == .resizeLeft || c == .resizeRight
    }

    private func shouldHandlePrimaryDrag(_ event: NSEvent) -> Bool {
        event.type == .leftMouseDragged && isPrimaryMouseDown && !event.modifierFlags.contains(.control)
    }

    private func expandedBounds(tolerance: CGFloat) -> NSRect {
        bounds.insetBy(dx: -tolerance, dy: -tolerance)
    }

    private func passedDragThreshold(from start: NSPoint, to current: NSPoint) -> Bool {
        let dx = current.x - start.x
        let dy = current.y - start.y
        return hypot(dx, dy) >= UI.dragThreshold
    }

    private func resolvedDependencies() -> (appState: AppState, panelSide: PanelSide)? {
        guard let panelSide else {
            log.error("[DragOverlay] critical: missing panelSide")
            return nil
        }
        return (appState, panelSide)
    }

    private func beginDrag(with urls: [URL], event: NSEvent) {
        dragState.didStart = true
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
        dragState = DragState(startPoint: nil, didStart: false, isResize: false)
        cachedSelection.removeAll()
        log.debug("[DragOverlay] drag ended op=\(operation.rawValue)")
    }
}
