//
//  DropNSView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

// MARK: - DropNSView
/// Handles panel background drops from external apps and SwiftUI thumbnail drags.
/// AppKit list drags are still routed by DragNSView, but SwiftUI .onDrag sessions
/// need a real NSDraggingDestination over the opposite panel.

import AppKit
import FileModelKit
import SwiftUI

@MainActor
final class DropNSView: NSView {
    weak var appState: AppState?
    weak var dragDropManager: DragDropManager?
    var panelSide: FavPanelSide!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(PasteboardURLResolver.fileURLPasteboardTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(PasteboardURLResolver.fileURLPasteboardTypes)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard acceptsDragHit else { return nil }
        return bounds.contains(point) ? self : nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        log.debug("[AppKitDrop] draggingEntered panel=\(panelSide!)")
        return allowedOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        allowedOperation(for: sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !PasteboardURLResolver.resolve(from: sender.draggingPasteboard).isEmpty
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard let dragDropManager, !dragDropManager.draggedFiles.isEmpty else { return }
        dragDropManager.setDropTarget(nil)
    }

    // MARK: - Perform External Drop
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let dragDropManager, let appState, let panelSide else {
            log.error("[AppKitDrop] missing dependencies")
            return false
        }
        if !dragDropManager.draggedFiles.isEmpty {
            let destination = appState.url(for: panelSide)
            log.info("[AppKitDrop] internal panel drop: \(dragDropManager.draggedFiles.count) file(s) → \(destination.lastPathComponent)")
            dragDropManager.prepareTransfer(
                files: dragDropManager.draggedFiles,
                to: destination,
                from: dragDropManager.dragSourcePanelSide
            )
            dragDropManager.endDrag()
            return true
        }
        let urls = PasteboardURLResolver.resolve(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            let types = sender.draggingPasteboard.types?.map(\.rawValue).joined(separator: ", ") ?? "none"
            log.debug("[AppKitDrop] pasteboard has no file URLs types=\(types)")
            return false
        }
        let destination = appState.url(for: panelSide)
        let files = urls.map { CustomFile(url: $0, resourceValues: URLResourceValues()) }
        log.info("[AppKitDrop] external drop: \(files.count) file(s) → \(destination.lastPathComponent)")
        dragDropManager.prepareTransfer(files: files, to: destination, from: nil)
        return true
    }

    private var acceptsDragHit: Bool {
        if let dragDropManager, !dragDropManager.draggedFiles.isEmpty { return true }
        guard let eventType = NSApp.currentEvent?.type else { return true }
        if isMouseDragEvent(eventType) { return true }
        return !isPassthroughMouseEvent(eventType)
    }

    private func isMouseDragEvent(_ eventType: NSEvent.EventType) -> Bool {
        switch eventType {
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return true
        default:
            return false
        }
    }

    private func isPassthroughMouseEvent(_ eventType: NSEvent.EventType) -> Bool {
        switch eventType {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown,
             .leftMouseUp, .rightMouseUp, .otherMouseUp,
             .scrollWheel:
            return true
        default:
            return false
        }
    }

    private func allowedOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        let supported = sender.draggingSourceOperationMask.intersection([.copy, .move])
        if supported.contains(.move) { return .move }
        if supported.contains(.copy) { return .copy }
        if sender.draggingSourceOperationMask.contains(.generic) { return .copy }
        if !PasteboardURLResolver.resolve(from: sender.draggingPasteboard).isEmpty { return .copy }
        return []
    }
}
