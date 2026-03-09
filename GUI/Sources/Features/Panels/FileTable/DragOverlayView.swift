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
            nsView.files = files
        }
    }

    final class DragNSView: NSView, NSDraggingSource {

        var panelSide: PanelSide!
        var files: [CustomFile] = []
        weak var dragDropManager: DragDropManager?
        weak var appState: AppState?

        override func mouseDragged(with event: NSEvent) {

            guard let appState else { return }

            let selectedFiles = appState.markedFiles(for: panelSide)

            guard !selectedFiles.isEmpty else { return }

            log.debug("[DragOverlay] starting AppKit drag with \(selectedFiles.count) file(s)")

            let draggingItems: [NSDraggingItem] = selectedFiles.map { file in

                let pasteboardItem = NSPasteboardItem()
                let fileURL = URL(fileURLWithPath: file)
                pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL)

                let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

                let frame = self.bounds
                draggingItem.setDraggingFrame(frame, contents: nil)

                return draggingItem
            }

            beginDraggingSession(with: draggingItems, event: event, source: self)
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            return .copy
        }
    }
