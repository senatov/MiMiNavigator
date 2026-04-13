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
    private var cachedSelection: [CustomFile] = []
    private var mouseMonitor: Any?
    private var dragMonitor: Any?

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
            // Resolve real CustomFile objects — preserves remote urlValue (ftp://host/path)
            // Never use fileURLWithPath on remote paths — it mangles them to file:///path
            cachedSelection = DragSelectionResolver.resolve(from: appState, side: panelSide)
        } else {
            cachedSelection = []
        }
    }

    // MARK: - Mouse Dragged
    /// Returns true if drag was initiated (event consumed).
    private func handleMouseDragged(_ event: NSEvent) -> Bool {
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

    private func configureDraggingSession(_ session: NSDraggingSession) {
        session.animatesToStartingPositionsOnCancelOrFail = false
        log.debug("[DragNSView] drag session configured: animatesToStartingPositionsOnCancelOrFail=false")
    }

    // MARK: - helper NSDraggingSource
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
            case .outsideApplication: return [.copy, .move]
            case .withinApplication: return [.move]
            @unknown default: return [.copy]
        }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard let dragDropManager, let appState, let window else { return }

        let dragContext = makeDragLocationContext(screenPoint: screenPoint, window: window)
        let hoverSide = resolvePanelSide(for: dragContext.windowPoint, in: window)
        let panelFrame = panelFrameInWindowCoordinates()
        let dirURL = dragDropManager.resolveDirectoryUnderCursor(
            windowPoint: dragContext.windowPoint,
            panelSide: hoverSide,
            appState: appState,
            panelFrame: panelFrame
        )

        logDragMove(
            dragImageScreenPoint: screenPoint,
            context: dragContext,
            hoverSide: hoverSide,
            panelFrame: panelFrame,
            targetURL: dirURL
        )
        dragDropManager.setDropTarget(dirURL)
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        defer {
            session.animatesToStartingPositionsOnCancelOrFail = false
            resetDragState()
        }

        if handleExternalDragEnd(screenPoint: screenPoint, operation: operation) {
            return
        }

        handleInternalDragEnd(screenPoint: screenPoint)
    }

    private func hasWindowContext(for event: NSEvent) -> Bool {
        guard let window = self.window else { return false }
        return event.window === window
    }

    private func hasDragDependencies() -> Bool {
        panelSide != nil && appState != nil
    }

    private func registerDragStart(files: [CustomFile]) {
        guard let panelSide else { return }
        dragDropManager?.startDrag(files: files, from: panelSide)
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

    private func resolveDropContext(
        screenPoint: NSPoint,
        window: NSWindow,
        appState: AppState,
        dragDropManager: DragDropManager
    ) -> (side: FavPanelSide, target: URL?) {
        let dragContext = makeDragLocationContext(screenPoint: screenPoint, window: window)
        let dropSide = resolvePanelSide(for: dragContext.windowPoint, in: window)
        let panelFrame = panelFrameInWindowCoordinates()
        let dirUnderCursor = dragDropManager.resolveDirectoryUnderCursor(
            windowPoint: dragContext.windowPoint,
            panelSide: dropSide,
            appState: appState,
            panelFrame: panelFrame
        )
        return (dropSide, dirUnderCursor)
    }

    private func resolveDropDestination(side: FavPanelSide, targetURL: URL?, appState: AppState) -> URL {
        targetURL ?? appState.url(for: side)
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

    private func handleExternalDragEnd(screenPoint: NSPoint, operation: NSDragOperation) -> Bool {
        guard operation != [] else { return false }

        if let draggedFiles = dragDropManager?.draggedFiles {
            animateDropPreviewIfPossible(screenPoint: screenPoint, files: draggedFiles)
        }

        dragDropManager?.endDrag()
        log.debug("[DragNSView] drag ended externally op=\(operation.rawValue)")
        return true
    }

    private func handleInternalDragEnd(screenPoint: NSPoint) {
        guard let dragDropManager, let appState, let panelSide, let window else {
            dragDropManager?.endDrag()
            log.debug("[DragNSView] drag ended op=0, no window context")
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

        animateDropPreviewIfPossible(screenPoint: screenPoint, files: files)
        dragDropManager.prepareTransfer(files: files, to: destination, from: panelSide)
    }

    private func makeDragLocationContext(screenPoint: NSPoint, window: NSWindow) -> DragLocationContext {
        let cursorScreenPoint = currentMouseScreenPoint(fallback: screenPoint)
        let probeScreenPoint = dropTargetProbeScreenPoint(from: cursorScreenPoint)
        let windowPoint = window.convertPoint(fromScreen: probeScreenPoint)
        return DragLocationContext(
            cursorScreenPoint: cursorScreenPoint,
            probeScreenPoint: probeScreenPoint,
            windowPoint: windowPoint
        )
    }

    private func resolvePanelSide(for windowPoint: NSPoint, in window: NSWindow) -> FavPanelSide {
        let contentWidth = window.contentView?.frame.width ?? window.frame.width
        let midX = contentWidth / 2
        return windowPoint.x < midX ? .left : .right
    }

    private func dragMoveTargetName(_ targetURL: URL?) -> String {
        targetURL?.lastPathComponent ?? "nil"
    }

    private func logDragMove(
        dragImageScreenPoint: NSPoint,
        context: DragLocationContext,
        hoverSide: FavPanelSide,
        panelFrame: NSRect,
        targetURL: URL?
    ) {
        let targetName = dragMoveTargetName(targetURL)
        let logMessage =
            "[DragNSView] movedTo dragImageScreen=\(dragImageScreenPoint) "
            + "cursorScreen=\(context.cursorScreenPoint) "
            + "probeScreen=\(context.probeScreenPoint) "
            + "window=\(context.windowPoint) "
            + "hoverSide=\(hoverSide) "
            + "panelFrame=\(panelFrame) "
            + "target=\(targetName)"
        log.debug(logMessage)
    }

    private func resetDragState() {
        dragState = DragState(startPoint: nil, didStart: false, isResize: false)
        cachedSelection = []
    }

    // MARK: - Helpers

    private func canAnimateDropPreview() -> Bool {
        window?.contentView?.superview != nil
    }

    private func animateDropPreviewIfPossible(screenPoint: NSPoint, files: [CustomFile]) {
        guard canAnimateDropPreview() else { return }
        guard let window,
            let contentView = window.contentView,
            let overlayContainer = contentView.superview
        else {
            return
        }
        guard let previewImage = makeDropPreviewImage(from: files) else { return }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let contentPoint = contentView.convert(windowPoint, from: nil)
        let overlayPoint = overlayContainer.convert(contentPoint, from: contentView)
        let previewFrame = dropPreviewFrame(centeredAt: overlayPoint)
        let previewView = NSImageView(frame: previewFrame)
        previewView.image = previewImage
        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.alphaValue = 1.0
        previewView.wantsLayer = true
        previewView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        previewView.layer?.position = CGPoint(x: previewFrame.midX, y: previewFrame.midY)

        overlayContainer.addSubview(previewView, positioned: .above, relativeTo: contentView)
        log.debug("[DragNSView] drop preview fade-out started at \(overlayPoint)")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = DragNSViewUI.dropPreviewFadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            previewView.animator().alphaValue = 0.0
            previewView.animator().frame = dropPreviewScaledFrame(from: previewFrame)
        } completionHandler: {
            DispatchQueue.main.async {
                previewView.removeFromSuperview()
            }
        }
    }

    private func makeDropPreviewImage(from files: [CustomFile]) -> NSImage? {
        let image = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: "Dragged file")
        image?.size = DragNSViewUI.dropPreviewSize
        return image
    }

    private func dropPreviewFrame(centeredAt point: NSPoint) -> NSRect {
        NSRect(
            x: point.x - (DragNSViewUI.dropPreviewSize.width / 2),
            y: point.y - (DragNSViewUI.dropPreviewSize.height / 2),
            width: DragNSViewUI.dropPreviewSize.width,
            height: DragNSViewUI.dropPreviewSize.height
        )
    }

    private func dropPreviewScaledFrame(from frame: NSRect) -> NSRect {
        let scaledWidth = frame.width * DragNSViewUI.dropPreviewEndScale
        let scaledHeight = frame.height * DragNSViewUI.dropPreviewEndScale
        return NSRect(
            x: frame.midX - (scaledWidth / 2),
            y: frame.midY - (scaledHeight / 2),
            width: scaledWidth,
            height: scaledHeight
        )
    }

    private func panelFrameInWindowCoordinates() -> NSRect {
        guard self.window != nil else { return .zero }
        return convert(bounds, to: nil)
    }

    private func currentMouseScreenPoint(fallback: NSPoint) -> NSPoint {
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
