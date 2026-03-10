    //
    //  Untitled.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 08.03.2026.
    //  Copyright © 2026 Senatov. All rights reserved.
    //

    // DragOverlayView.swift

    import AppKit
    import FileModelKit
    import SwiftUI

    struct DragOverlayView: NSViewRepresentable {
        @Environment(AppState.self) var appState
        @Environment(DragDropManager.self) var dragDropManager

        let panelSide: PanelSide
        let files: [CustomFile]

        func makeNSView(context: Context) -> DragNSView {
            let view = DragNSView()
            view.panelSide = panelSide
            view.files = files
            view.dragDropManager = dragDropManager
            view.appState = appState
            return view
        }

        func updateNSView(_ nsView: DragNSView, context: Context) {
            nsView.panelSide = panelSide
            nsView.files = files
            nsView.dragDropManager = dragDropManager
            nsView.appState = appState
        }
    }

    final class DragNSView: NSView, NSDraggingSource {

        var panelSide: PanelSide!
        var files: [CustomFile] = []
        weak var dragDropManager: DragDropManager?
        weak var appState: AppState?

        private var mouseDownPoint: NSPoint = .zero
        private let dragThreshold: CGFloat = 4.0
        private var didStartDragging = false

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownPoint = convert(event.locationInWindow, from: nil)
            didStartDragging = false
            super.mouseDown(with: event)
        }

        override func mouseUp(with event: NSEvent) {
            didStartDragging = false
            super.mouseUp(with: event)
        }

        override func mouseDragged(with event: NSEvent) {

            guard !didStartDragging else { return }
            guard let appState, let panelSide else { return }

            let currentPoint = convert(event.locationInWindow, from: nil)
            let deltaX = currentPoint.x - mouseDownPoint.x
            let deltaY = currentPoint.y - mouseDownPoint.y
            let dragDistance = hypot(deltaX, deltaY)

            guard dragDistance >= dragThreshold else {
                super.mouseDragged(with: event)
                return
            }

            let selectedPaths = appState.markedFiles(for: panelSide)
            let selectedURLs = selectedPaths.map { URL(fileURLWithPath: $0) }

            guard !selectedURLs.isEmpty else { return }

            didStartDragging = true
            log.debug("[DragOverlay] starting AppKit drag with \(selectedURLs.count) file(s)")

            let draggingItems: [NSDraggingItem] = selectedURLs.map { fileURL in
                let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                icon.size = NSSize(width: 32, height: 32)
                let draggingFrame = NSRect(origin: .zero, size: icon.size)
                draggingItem.setDraggingFrame(draggingFrame, contents: icon)
                return draggingItem
            }

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
