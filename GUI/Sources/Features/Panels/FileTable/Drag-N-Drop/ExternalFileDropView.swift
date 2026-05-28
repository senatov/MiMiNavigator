// ExternalFileDropView.swift
// MiMiNavigator
//
// Description: Root-level AppKit drop receiver for file drags from Finder and other apps.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Window External File Drop Installer
struct WindowExternalFileDropInstaller: NSViewRepresentable {
    let appState: AppState
    let dragDropManager: DragDropManager
    let leftPanelWidth: CGFloat
    let containerWidth: CGFloat

    func makeNSView(context: Context) -> ExternalFileDropNSView {
        let view = ExternalFileDropNSView(frame: .zero)
        updateReceiver(
            view,
            appState: appState,
            dragDropManager: dragDropManager,
            leftPanelWidth: leftPanelWidth,
            containerWidth: containerWidth
        )
        return view
    }

    func updateNSView(_ nsView: ExternalFileDropNSView, context: Context) {
        updateReceiver(
            nsView,
            appState: appState,
            dragDropManager: dragDropManager,
            leftPanelWidth: leftPanelWidth,
            containerWidth: containerWidth
        )
    }

    // MARK: - Update Receiver
    private func updateReceiver(
        _ view: ExternalFileDropNSView,
        appState: AppState,
        dragDropManager: DragDropManager,
        leftPanelWidth: CGFloat,
        containerWidth: CGFloat
    ) {
        view.appState = appState
        view.dragDropManager = dragDropManager
        view.leftPanelWidth = leftPanelWidth
        view.containerWidth = containerWidth
    }
}

// MARK: - External File Drop NSView
@MainActor
final class ExternalFileDropNSView: NSView {
    weak var appState: AppState?
    weak var dragDropManager: DragDropManager?
    var leftPanelWidth: CGFloat = 0
    var containerWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(PasteboardURLResolver.fileURLPasteboardTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(PasteboardURLResolver.fileURLPasteboardTypes)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point), acceptsPointerEvent else { return nil }
        return self
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = PasteboardURLResolver.resolve(from: sender.draggingPasteboard)
        log.info("[ExternalDrop] entered urls=\(urls.count) side=\(panelSide(for: sender.draggingLocation))")
        return urls.isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = PasteboardURLResolver.resolve(from: sender.draggingPasteboard)
        return urls.isEmpty ? [] : .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = PasteboardURLResolver.resolve(from: sender.draggingPasteboard)
        if urls.isEmpty {
            log.warning("[ExternalDrop] prepare rejected: no file URLs types=\(pasteboardTypes(sender))")
        }
        return !urls.isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let appState, let dragDropManager else {
            log.error("[ExternalDrop] missing dependencies")
            return false
        }
        let urls = PasteboardURLResolver.resolve(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            log.warning("[ExternalDrop] perform rejected: no file URLs types=\(pasteboardTypes(sender))")
            return false
        }
        let side = panelSide(for: sender.draggingLocation)
        let destination = appState.url(for: side)
        let files = urls.map { CustomFile(url: $0, resourceValues: URLResourceValues()) }
        log.info("[ExternalDrop] drop \(files.count) file(s) → \(side) \(destination.path)")
        appState.focusedPanel = side
        dragDropManager.prepareTransfer(files: files, to: destination, from: nil)
        return true
    }

    private var acceptsPointerEvent: Bool {
        guard let eventType = NSApp.currentEvent?.type else { return true }
        switch eventType {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown,
             .leftMouseUp, .rightMouseUp, .otherMouseUp,
             .scrollWheel:
            return false
        default:
            return true
        }
    }

    private func panelSide(for point: NSPoint) -> FavPanelSide {
        let dividerX = max(0, min(leftPanelWidth, containerWidth))
        return point.x < dividerX ? .left : .right
    }

    private func pasteboardTypes(_ sender: NSDraggingInfo) -> String {
        sender.draggingPasteboard.types?.map(\.rawValue).joined(separator: ", ") ?? "none"
    }
}
