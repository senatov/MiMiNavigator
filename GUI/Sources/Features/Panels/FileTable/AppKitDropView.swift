    //
    //  AppKitDropView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 10.03.2026.
    //  Copyright © 2026 Senatov. All rights reserved.
    //

    import AppKit
    import FileModelKit
    import SwiftUI

    struct AppKitDropView: NSViewRepresentable {

        let panelSide: PanelSide
        let appState: AppState
        let dragDropManager: DragDropManager

        func makeNSView(context: Context) -> DropNSView {
            let view = DropNSView()
            view.panelSide = panelSide
            view.appState = appState
            view.dragDropManager = dragDropManager
            return view
        }

        func updateNSView(_ nsView: DropNSView, context: Context) {
            nsView.panelSide = panelSide
            nsView.appState = appState
            nsView.dragDropManager = dragDropManager
        }
    }

    @MainActor
    final class DropNSView: NSView {

        weak var appState: AppState?
        weak var dragDropManager: DragDropManager?
        var panelSide: PanelSide!

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            registerForDraggedTypes([.fileURL])
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            registerForDraggedTypes([.fileURL])
        }

        /// Do not intercept normal mouse events so the underlying SwiftUI view
        /// (file rows, selection, context menu, etc.) keeps working.
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            sender.draggingSourceOperationMask.intersection([.copy, .move])
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            guard
                let dragDropManager,
                let appState
            else { return false }
            let pasteboard = sender.draggingPasteboard
            log.debug("[AppKitDrop] pasteboard types: \(pasteboard.types ?? [])")
            var items: [URL] = []

            // 1. Best approach: iterate individual pasteboard items (each NSDraggingItem → 1 pbItem)
            if let pbItems = pasteboard.pasteboardItems {
                for pbItem in pbItems {
                    if let data = pbItem.data(forType: .fileURL),
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        items.append(url)
                    }
                }
            }

            // 2. Fallback: NSFilenamesPboardType (Finder‑style multi file drag, deprecated but reliable)
            if items.isEmpty,
               let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
                items = paths.map { URL(fileURLWithPath: $0) }
            }

            // 3. Last resort: generic NSURL reader
            if items.isEmpty,
               let urls = pasteboard.readObjects(
                   forClasses: [NSURL.self],
                   options: [.urlReadingFileURLsOnly: true]
               ) as? [URL] {
                items = urls
            }

            // Deduplicate (same file may appear via multiple pasteboard representations)
            var seen = Set<String>()
            let uniqueItems = items.filter { seen.insert($0.path).inserted }

            guard !uniqueItems.isEmpty else {
                log.debug("[AppKitDrop] pasteboard contains no file URLs")
                return false
            }
            let files = uniqueItems.map { CustomFile(url: $0, resourceValues: URLResourceValues()) }
            let destination: URL
            guard let panelSide else {
                log.error("[AppKitDrop] panelSide is nil")
                return false
            }
            destination = appState.url(for: panelSide)
            log.debug("[AppKitDrop] dropping \(files.count) files → \(destination.path)")
            dragDropManager.prepareTransfer(
                files: files,
                to: destination,
                from: nil
            )
            return true
        }
    }
