// DropTargetModifier.swift
// MiMiNavigator
//
// Extracted from DragPreviewView.swift on 25.03.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: SwiftUI drop target modifier — prefers internal draggedFiles, falls back to URL decoding

import FileModelKit
import SwiftUI


// MARK: - DropTargetModifier
/// Prefers DragDropManager.draggedFiles for internal drags (preserves multi-file selection).
/// Falls back to URL decoding for external drags (e.g. from Finder).
struct DropTargetModifier: ViewModifier {
    let isValidTarget: Bool
    @Binding var isDropTargeted: Bool
    let onDrop: ([CustomFile]) -> Bool
    let onTargetChange: (Bool) -> Void
    @Environment(DragDropManager.self) var dragDropManager


    func body(content: Content) -> some View {
        // Only register .dropDestination for directories.
        // Non-directory rows must NOT register — otherwise SwiftUI consumes
        // the drop event even when returning false, blocking parent handler.
        if isValidTarget {
            content
                .dropDestination(for: URL.self) { droppedURLs, _ in
                    let internalFiles = dragDropManager.draggedFiles
                    if !internalFiles.isEmpty {
                        log.debug("[DropTarget] internal drop: \(internalFiles.count) file(s)")
                        return onDrop(internalFiles)
                    }
                    let files = Self.resolveExternalURLs(droppedURLs)
                    guard !files.isEmpty else {
                        log.warning("[DropTarget] no valid file URLs in external drop")
                        return false
                    }
                    log.debug("[DropTarget] external drop: \(files.count) file(s)")
                    return onDrop(files)
                } isTargeted: { targeted in
                    onTargetChange(targeted)
                }
        } else {
            content
        }
    }


    // MARK: - Resolve External URLs
    /// Decode file URLs from external drag (Finder, other apps).
    static func resolveExternalURLs(_ urls: [URL]) -> [CustomFile] {
        urls.compactMap { url -> CustomFile? in
            guard url.isFileURL else { return nil }
            let path = url.standardizedFileURL.path
            guard !path.isEmpty, !path.contains("\0"),
                  FileManager.default.fileExists(atPath: path) else { return nil }
            return CustomFile(path: path)
        }
    }
}
