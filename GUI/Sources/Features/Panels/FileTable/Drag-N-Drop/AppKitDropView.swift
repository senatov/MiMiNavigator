// AppKitDropView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppKit drop target overlay — receives drops from EXTERNAL apps (Finder, etc.)
// Internal panel-to-panel drops are handled by DragNSView directly.

import AppKit
import FileModelKit
import SwiftUI


// MARK: - AppKitDropView
struct AppKitDropView: NSViewRepresentable {
    let panelSide: FavPanelSide
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


// MARK: - DropNSView
/// Handles EXTERNAL drops only (from Finder, other apps).
/// For internal drag between panels, hitTest returns nil — DragNSView handles routing directly.
/// External drags bypass hitTest via registerForDraggedTypes (cross-process AppKit behavior).
@MainActor
final class DropNSView: NSView {
    weak var appState: AppState?
    weak var dragDropManager: DragDropManager?
    var panelSide: FavPanelSide!


    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }


    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }


    /// Always nil — never intercept mouse events or internal drags.
    /// External drags from other processes bypass hitTest via registerForDraggedTypes.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }


    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        log.debug("[AppKitDrop] draggingEntered panel=\(panelSide!) external")
        return sender.draggingSourceOperationMask.intersection([.copy, .move])
    }


    // MARK: - Perform External Drop
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let dragDropManager, let appState, let panelSide else {
            log.error("[AppKitDrop] missing dependencies")
            return false
        }
        let urls = PasteboardURLResolver.resolve(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            log.debug("[AppKitDrop] pasteboard has no file URLs")
            return false
        }
        let destination = appState.url(for: panelSide)
        let files = urls.map { CustomFile(url: $0, resourceValues: URLResourceValues()) }
        log.info("[AppKitDrop] external drop: \(files.count) file(s) → \(destination.lastPathComponent)")
        dragDropManager.prepareTransfer(files: files, to: destination, from: nil)
        return true
    }
}
