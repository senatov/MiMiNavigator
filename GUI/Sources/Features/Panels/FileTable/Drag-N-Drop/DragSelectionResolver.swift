// DragSelectionResolver.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 16.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Resolves which files participate in a drag session.
//   Uses filesForOperation (marked first, then selected) to get real CustomFile objects.
//   For remote files returns their actual remote urlValue — never fileURLWithPath.
//   resolveForDrag: Finder-style — file under cursor wins when not in current selection.

import AppKit
import FileModelKit

struct DragSelectionResolver {

    @MainActor
    static func resolve(from appState: AppState, side: FavPanelSide) -> [CustomFile] {
        appState.filesForOperation(on: side)
    }


    @MainActor
    static func resolveURLs(from appState: AppState, side: FavPanelSide) -> [URL] {
        resolve(from: appState, side: side).map { $0.urlValue }
    }


    /// Finder-style drag resolution: if mouse is over a file that belongs to
    /// marked/selected set → drag the whole set; otherwise drag just that file.
    /// Falls back to `resolve` when row hit-test fails.
    @MainActor
    static func resolveForDrag(
        from appState: AppState,
        side: FavPanelSide,
        windowPoint: NSPoint,
        panelFrame: NSRect
    ) -> [CustomFile] {
        guard let hitFile = fileUnderCursor(
            windowPoint: windowPoint,
            panelSide: side,
            appState: appState,
            panelFrame: panelFrame
        ) else {
            return resolve(from: appState, side: side)
        }
        if ParentDirectoryEntry.isParentEntry(hitFile) { return [] }
        let opFiles = appState.filesForOperation(on: side)
        if opFiles.contains(where: { $0.id == hitFile.id }) {
            return opFiles
        }
        return [hitFile]
    }


    /// Row hit-test — same geometry as DragDropManager.resolveDirectoryUnderCursor
    /// but returns any file, not just directories.
    @MainActor
    private static func fileUnderCursor(
        windowPoint: NSPoint,
        panelSide: FavPanelSide,
        appState: AppState,
        panelFrame: NSRect
    ) -> CustomFile? {
        let headerHeight: CGFloat = 26
        let rowHeight = FilePanelStyle.rowHeight
        let yInPanel = panelFrame.maxY - windowPoint.y
        let rowY = yInPanel - headerHeight
        guard rowY >= 0 else { return nil }
        let rowIndex = Int(floor(rowY / rowHeight))
        let files = appState.displayedFiles(for: panelSide)
        guard rowIndex >= 0, rowIndex < files.count else { return nil }
        return files[rowIndex]
    }
}
