// DragNSView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppKit drag source — initiates NSDraggingSession for multi-file drag from list mode

import AppKit
import FileModelKit
import SwiftUI


// MARK: - DragNSView
@MainActor
final class DragNSView: NSView, NSDraggingSource {
    var panelSide: FavPanelSide?
    weak var dragDropManager: DragDropManager?
    weak var appState: AppState?
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
        fatalError("init(coder:) not supported")
    }


    /// Passthrough — let SwiftUI handle clicks, selection, context menu.
    /// Drag is initiated via NSEvent local monitor.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }


    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { installMonitors() }
        else { removeMonitors() }
    }


    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil { removeMonitors() }
    }


    // MARK: - Monitor Installation
    private func installMonitors() {
        removeMonitors()
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.handleMouseDown(event)
            return event
        }
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            if let self, self.handleMouseDragged(event) { return nil }
            return event
        }
    }


    private func removeMonitors() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
        if let m = dragMonitor { NSEvent.removeMonitor(m); dragMonitor = nil }
    }


    // MARK: - Mouse Down
    private func handleMouseDown(_ event: NSEvent) {
        guard let window = self.window, event.window === window else { return }
        guard event.type == .leftMouseDown, isPrimaryMouseDown,
              !event.modifierFlags.contains(.control) else { return }
        let locWindow = event.locationInWindow
        let loc = convert(locWindow, from: nil)
        guard bounds.contains(loc) else { return }
        dragState.startPoint = locWindow
        dragState.didStart = false
        dragState.isResize = isResizeCursor
        if let panelSide, let appState {
            cachedSelection = DragSelectionResolver.resolve(from: appState, side: panelSide)
        } else {
            cachedSelection = []
        }
    }


    // MARK: - Mouse Dragged
    /// Returns true if drag was initiated (event consumed).
    private func handleMouseDragged(_ event: NSEvent) -> Bool {
        guard let window = self.window, event.window === window else { return false }
        guard shouldHandlePrimaryDrag(event) else { return false }
        guard !dragState.didStart, !dragState.isResize else { return false }
        guard let mouseDownPoint = dragState.startPoint else { return false }
        guard panelSide != nil, appState != nil else { return false }
        let currentWindowPoint = event.locationInWindow
        let currentPoint = convert(currentWindowPoint, from: nil)
        guard expandedBounds(tolerance: UI.dragStartTolerance).contains(currentPoint) else { return false }
        guard passedDragThreshold(from: mouseDownPoint, to: currentWindowPoint) else { return false }
        guard !cachedSelection.isEmpty else { return false }
        beginDrag(with: cachedSelection, event: event)
        return true
    }


    // MARK: - Begin Drag
    private func beginDrag(with urls: [URL], event: NSEvent) {
        dragState.didStart = true
        let files = urls.map { CustomFile(path: $0.path) }
        if let panelSide {
            dragDropManager?.startDrag(files: files, from: panelSide)
        }
        let mouseInView = convert(event.locationInWindow, from: nil)
        log.debug("[DragNSView] starting drag with \(urls.count) file(s) at \(mouseInView)")
        let draggingItems = DragSessionBuilder.makeDraggingItems(from: urls, at: mouseInView)
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }


    // MARK: - NSDraggingSource
    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
            case .outsideApplication: return [.copy, .move]
            case .withinApplication: return [.move]
            @unknown default: return [.copy]
        }
    }


    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }


    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        defer {
            dragState = DragState(startPoint: nil, didStart: false, isResize: false)
            cachedSelection.removeAll()
        }
        // If AppKit resolved the drop externally (Finder accepted it), op != 0 → done
        if operation != [] {
            dragDropManager?.endDrag()
            log.debug("[DragNSView] drag ended externally op=\(operation.rawValue)")
            return
        }
        // Internal drop: AppKit can't route between SwiftUI-embedded NSViews,
        // so we resolve the target panel ourselves from screen coordinates.
        guard let dragDropManager, let appState, let panelSide,
              let window = self.window else {
            dragDropManager?.endDrag()
            log.debug("[DragNSView] drag ended op=0, no window context")
            return
        }
        let files = dragDropManager.draggedFiles
        guard !files.isEmpty else {
            dragDropManager.endDrag()
            return
        }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let contentWidth = window.contentView?.frame.width ?? window.frame.width
        let midX = contentWidth / 2
        let dropSide: FavPanelSide = windowPoint.x < midX ? .left : .right
        log.debug("[DragNSView] drop resolve: windowPt.x=\(windowPoint.x) midX=\(midX) → dropSide=\(dropSide) sourceSide=\(panelSide)")
        let destination = appState.url(for: dropSide)
        // prepareTransfer already rejects same-dir drops; allow same-panel drops
        // because user might be dropping INTO a subfolder on the same panel
        log.info("[DragNSView] internal drop: \(files.count) file(s) → \(dropSide) (\(destination.lastPathComponent))")
        dragDropManager.prepareTransfer(files: files, to: destination, from: panelSide)
    }


    // MARK: - Helpers
    private var isPrimaryMouseDown: Bool { NSEvent.pressedMouseButtons == 1 }


    private var isResizeCursor: Bool {
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
        hypot(current.x - start.x, current.y - start.y) >= UI.dragThreshold
    }
}
