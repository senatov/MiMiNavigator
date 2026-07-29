// DragNSView+Session.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: NSDraggingSession lifecycle for the list-mode drag source.

import AppKit

// MARK: - Drag Session
extension DragNSView {
    func configureDraggingSession(_ session: NSDraggingSession) {
        session.animatesToStartingPositionsOnCancelOrFail = false
        session.draggingFormation = cachedSelection.count > 1 ? .stack : .default
        log.debug("[DragNSView] drag session configured formation=\(session.draggingFormation.rawValue)")
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
            case .outsideApplication:
                return dragContainsAppManagedNetworkMount ? [.copy] : [.copy, .move]
            case .withinApplication:
                return [.move]
            @unknown default:
                return [.copy]
        }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard let dragDropManager, let appState, let window else { return }
        let cursorScreenPoint = currentMouseScreenPoint(fallback: screenPoint)
        guard DragDestinationWindowResolver.isWindowTopmost(window, at: cursorScreenPoint) else {
            dragDropManager.setDropTarget(nil)
            return
        }
        let dropContext = resolveDropContext(
            screenPoint: screenPoint,
            window: window,
            appState: appState,
            dragDropManager: dragDropManager
        )
        logDragMove(hoverSide: dropContext.side, targetURL: dropContext.target)
        dragDropManager.setDropTarget(dropContext.target)
        dragDropManager.setDropDestinationOverride(dropContext.isToParent ? dropContext.target : nil)
        updateToParentContact(dropContext.isToParent, session: session)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        session.animatesToStartingPositionsOnCancelOrFail = false
        defer { resetDragState() }
        if handleExternalDragEnd(screenPoint: screenPoint, operation: operation) { return }
        handleInternalDragEnd(screenPoint: screenPoint)
    }
}
