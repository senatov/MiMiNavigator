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
    var cachedSelection: [CustomFile] = []
    private var mouseMonitor: Any?
    private var dragMonitor: Any?
    private var isToParentContact = false
    private var lastLoggedHoverSide: FavPanelSide?
    private var lastLoggedTargetPath: String?

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
        if window != nil { installMonitors() } else { removeMonitors() }
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
        if let m = mouseMonitor {
            NSEvent.removeMonitor(m)
            mouseMonitor = nil
        }
        if let m = dragMonitor {
            NSEvent.removeMonitor(m)
            dragMonitor = nil
        }
    }

    // MARK: - Mouse Down
    private func handleMouseDown(_ event: NSEvent) {
        guard canStartPanelDrag else { return }
        guard hasWindowContext(for: event) else { return }
        guard event.type == .leftMouseDown, isPrimaryMouseDown,
            !event.modifierFlags.contains(.control)
        else { return }
        let locWindow = event.locationInWindow
        let loc = convert(locWindow, from: nil)
        guard bounds.contains(loc) else { return }
        dragState.startPoint = locWindow
        dragState.didStart = false
        dragState.isResize = isResizeCursor
        if let panelSide, let appState {
            // Finder-style: resolve file under cursor, not stale selection
            let panelFrame = panelFrameInWindowCoordinates()
            cachedSelection = DragSelectionResolver.resolveForDrag(
                from: appState,
                side: panelSide,
                windowPoint: locWindow,
                panelFrame: panelFrame
            )
        } else {
            cachedSelection = []
        }
    }

    // MARK: - Mouse Dragged
    /// Returns true if drag was initiated (event consumed).
    private func handleMouseDragged(_ event: NSEvent) -> Bool {
        guard canStartPanelDrag else {
            resetDragState()
            return false
        }
        guard hasWindowContext(for: event) else { return false }
        guard shouldHandlePrimaryDrag(event) else { return false }
        guard !dragState.didStart, !dragState.isResize else { return false }
        guard let mouseDownPoint = dragState.startPoint else { return false }
        guard hasDragDependencies() else { return false }
        let currentWindowPoint = event.locationInWindow
        let currentPoint = convert(currentWindowPoint, from: nil)
        guard expandedBounds(tolerance: DragNSViewUI.dragStartTolerance).contains(currentPoint) else { return false }
        guard passedDragThreshold(from: mouseDownPoint, to: currentWindowPoint) else { return false }
        guard !cachedSelection.isEmpty else { return false }
        beginDrag(with: cachedSelection, event: event)
        return true
    }

    // MARK: - Begin Drag
    private func beginDrag(with files: [CustomFile], event: NSEvent) {
        dragState.didStart = true
        registerDragStart(files: files)
        let mouseInView = convert(event.locationInWindow, from: nil)
        log.debug("[DragNSView] starting drag with \(files.count) file(s) at \(mouseInView)")
        let draggingItems = makeDraggingItems(from: files, at: mouseInView)
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        configureDraggingSession(session)
    }

    private func hasWindowContext(for event: NSEvent) -> Bool {
        guard let window = self.window else { return false }
        return event.window === window
    }

    private func hasDragDependencies() -> Bool {
        panelSide != nil && appState != nil
    }

    private var canStartPanelDrag: Bool {
        CntMenuCoord.shared.activeDialog == nil
            && dragDropManager?.showConfirmationDialog != true
            && window?.attachedSheet == nil
            && NSApp.modalWindow == nil
    }

    private func registerDragStart(files: [CustomFile]) {
        guard let panelSide, let appState else { return }
        dragDropManager?.startDrag(files: files, from: panelSide, appState: appState)
    }

    private func makeDraggingItems(from files: [CustomFile], at mouseInView: NSPoint) -> [NSDraggingItem] {
        let urls = pasteboardURLs(from: files)
        return DragSessionBuilder.makeDraggingItems(from: urls, at: mouseInView)
    }

    private func pasteboardURLs(from files: [CustomFile]) -> [URL] {
        files.map { file in
            let url = file.urlValue
            if AppState.isRemotePath(url) {
                return URL(fileURLWithPath: file.pathStr)
            }
            return url
        }
    }

    var dragContainsAppManagedNetworkMount: Bool {
        cachedSelection.contains { AppState.isAppManagedNetworkMountPath($0.urlValue) }
    }

    private func resolveDropContext(
        screenPoint: NSPoint,
        window: NSWindow,
        appState: AppState,
        dragDropManager: DragDropManager
    ) -> (side: FavPanelSide, target: URL?) {
        let dragContext = makeDragLocationContext(screenPoint: screenPoint, window: window)
        let dropSide = dragDropManager.panelSide(atWindowX: dragContext.windowPoint.x)
        let panelFrame = panelFrameInWindowCoordinates()
        let dirUnderCursor = dragDropManager.resolveDirectoryUnderCursor(
            windowPoint: dragContext.windowPoint,
            panelSide: dropSide,
            appState: appState,
            panelFrame: panelFrame
        )
        return (dropSide, dirUnderCursor ?? dragDropManager.dropDestinationOverride)
    }

    private func resolveDropDestination(side: FavPanelSide, targetURL: URL?, appState: AppState) -> URL {
        targetURL ?? appState.url(for: side)
    }

    func resolveToParentDestination(
        windowPoint: NSPoint,
        panelSide: FavPanelSide,
        appState: AppState,
        panelFrame: NSRect
    ) -> URL? {
        guard panelSide == self.panelSide else { return nil }
        let stripFrame = NSRect(
            x: panelFrame.minX,
            y: panelFrame.maxY - ParentEntryStripView.rowHeight,
            width: max(0, panelFrame.width - 69),
            height: ParentEntryStripView.rowHeight
        )
        guard stripFrame.contains(windowPoint) else { return nil }
        let state = appState.archiveState(for: panelSide)
        guard state.isInsideArchive else { return nil }
        let currentURL = appState.url(for: panelSide)
        if state.isAtArchiveRoot(currentPath: currentURL.path), let archiveURL = state.archiveURL {
            return archiveURL.deletingLastPathComponent()
        }
        return currentURL.deletingLastPathComponent()
    }

    func updateToParentContact(_ contact: Bool, session: NSDraggingSession) {
        guard isToParentContact != contact, let firstFile = cachedSelection.first else { return }
        isToParentContact = contact
        let preview = DragSessionBuilder.makePreviewImage(
            firstURL: firstFile.urlValue,
            itemCount: cachedSelection.count,
            isContact: contact
        )
        session.enumerateDraggingItems(
            options: [],
            for: nil,
            classes: [NSURL.self],
            searchOptions: [:]
        ) { item, index, _ in
            guard index == 0 else { return }
            item.setDraggingFrame(item.draggingFrame, contents: preview)
        }
        log.debug("[ToParent] contact=\(contact)")
    }

    private func shouldIgnoreInternalDrop(
        from sourceSide: FavPanelSide,
        to destinationSide: FavPanelSide,
        targetURL: URL?,
        screenPoint: NSPoint,
        window: NSWindow
    ) -> Bool {
        guard sourceSide == destinationSide else { return false }
        guard targetURL == nil else { return false }
        return isDropNearDragStart(screenPoint: screenPoint, window: window)
            || isDropInsideSourcePanel(screenPoint: screenPoint, window: window)
    }

    private func isDropNearDragStart(screenPoint: NSPoint, window: NSWindow) -> Bool {
        guard let startWindowPoint = dragState.startPoint else { return false }
        let endWindowPoint = window.convertPoint(fromScreen: screenPoint)
        let distance = hypot(endWindowPoint.x - startWindowPoint.x, endWindowPoint.y - startWindowPoint.y)
        return distance <= DragNSViewUI.samePanelDropReturnTolerance
    }

    private func isDropInsideSourcePanel(screenPoint: NSPoint, window: NSWindow) -> Bool {
        let endWindowPoint = window.convertPoint(fromScreen: screenPoint)
        let panelFrame = panelFrameInWindowCoordinates()
        return panelFrame.contains(endWindowPoint)
    }

    func handleExternalDragEnd(screenPoint: NSPoint, operation: NSDragOperation) -> Bool {
        guard operation != [] else { return false }

        dragDropManager?.endDrag()
        log.debug("[DragNSView] drag ended externally op=\(operation.rawValue)")
        return true
    }

    func handleInternalDragEnd(screenPoint: NSPoint) {
        guard let dragDropManager, let appState, let panelSide, let window else {
            dragDropManager?.endDrag()
            log.debug("[DragNSView] drag ended op=0, no window context")
            return
        }
        if dragDropManager.pendingOperation != nil || dragDropManager.showConfirmationDialog {
            dragDropManager.endDrag()
            log.debug("[DragNSView] internal drop already handled by SwiftUI destination")
            return
        }
        let cursorScreenPoint = currentMouseScreenPoint(fallback: screenPoint)
        guard DragDestinationWindowResolver.isWindowTopmost(window, at: cursorScreenPoint) else {
            dragDropManager.endDrag()
            log.info("[DragNSView] internal drop ignored: MiMiNavigator is obscured at release point")
            return
        }

        let files = dragDropManager.draggedFiles
        guard !files.isEmpty else {
            dragDropManager.endDrag()
            log.debug("[DragNSView] drag ended op=0, draggedFiles is empty")
            return
        }
        let dropContext = resolveDropContext(
            screenPoint: screenPoint,
            window: window,
            appState: appState,
            dragDropManager: dragDropManager
        )
        let dropSide = dropContext.side
        let dirUnderCursor = dropContext.target

        if shouldIgnoreInternalDrop(
            from: panelSide,
            to: dropSide,
            targetURL: dirUnderCursor,
            screenPoint: screenPoint,
            window: window
        ) {
            dragDropManager.endDrag()
            log.info("[DragNSView] internal drop ignored: returned to origin panel without valid target")
            return
        }

        let destination = resolveDropDestination(side: dropSide, targetURL: dirUnderCursor, appState: appState)
        log.info(
            "[DragNSView] internal drop: \(files.count) file(s) → \(dropSide) (\(destination.lastPathComponent)) subdir=\(dirUnderCursor != nil)"
        )

        dragDropManager.prepareTransfer(files: files, to: destination, from: panelSide)
    }

    func makeDragLocationContext(screenPoint: NSPoint, window: NSWindow) -> DragLocationContext {
        let cursorScreenPoint = currentMouseScreenPoint(fallback: screenPoint)
        let probeScreenPoint = dropTargetProbeScreenPoint(from: cursorScreenPoint)
        let windowPoint = window.convertPoint(fromScreen: probeScreenPoint)
        return DragLocationContext(
            cursorScreenPoint: cursorScreenPoint,
            probeScreenPoint: probeScreenPoint,
            windowPoint: windowPoint
        )
    }

    private func dragMoveTargetName(_ targetURL: URL?) -> String {
        targetURL?.lastPathComponent ?? "nil"
    }

    func logDragMove(
        hoverSide: FavPanelSide,
        targetURL: URL?
    ) {
        let targetPath = targetURL?.standardizedFileURL.path
        guard lastLoggedHoverSide != hoverSide || lastLoggedTargetPath != targetPath else { return }
        lastLoggedHoverSide = hoverSide
        lastLoggedTargetPath = targetPath
        log.debug("[DragNSView] hover panel=\(hoverSide) target=\(dragMoveTargetName(targetURL))")
    }

    func resetDragState() {
        dragState = DragState(startPoint: nil, didStart: false, isResize: false)
        cachedSelection = []
        isToParentContact = false
        lastLoggedHoverSide = nil
        lastLoggedTargetPath = nil
    }

    // MARK: - Helpers
    func panelFrameInWindowCoordinates() -> NSRect {
        guard self.window != nil else { return .zero }
        return convert(bounds, to: nil)
    }

    func currentMouseScreenPoint(fallback: NSPoint) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        if mouseLocation == .zero {
            return fallback
        }
        return mouseLocation
    }

    private func dropTargetProbeScreenPoint(from cursorScreenPoint: NSPoint) -> NSPoint {
        NSPoint(
            x: cursorScreenPoint.x,
            y: cursorScreenPoint.y + DragNSViewUI.dropTargetProbeYOffset
        )
    }

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
        hypot(current.x - start.x, current.y - start.y) >= DragNSViewUI.dragThreshold
    }
}
