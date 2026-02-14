// DragPreviewView.swift
// MiMiNavigator
//
// Extracted from FileRow.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Visual drag preview for file drag-and-drop operations

import AppKit
import SwiftUI

// MARK: - Drag Preview View
/// Shows file icon + name during drag operations, with optional multi-file badge
struct DragPreviewView: View {
    let file: CustomFile
    var additionalCount: Int = 0

    private var totalCount: Int { additionalCount + 1 }

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                    .resizable()
                    .frame(width: 32, height: 32)

                // Badge showing total count for multi-file drag
                if totalCount > 1 {
                    Text("\(totalCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                        .offset(x: 6, y: -4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.nameStr)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if totalCount > 1 {
                    Text("and \(additionalCount) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Drop Target Modifier
/// Prefers DragDropManager.draggedFiles for internal drags (preserves multi-file selection).
/// Falls back to URL decoding for external drags (e.g. from Finder).
struct DropTargetModifier: ViewModifier {
    let isValidTarget: Bool
    @Binding var isDropTargeted: Bool
    let onDrop: ([CustomFile]) -> Bool
    let onTargetChange: (Bool) -> Void
    @Environment(DragDropManager.self) var dragDropManager

    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self) { droppedURLs, _ in
                // Internal drag: use draggedFiles (preserves full multi-selection)
                let internalFiles = dragDropManager.draggedFiles
                if !internalFiles.isEmpty {
                    log.debug("[DropTarget] using \(internalFiles.count) internal draggedFiles")
                    return onDrop(internalFiles)
                }
                // External drag (Finder etc.): decode from URLs with validation
                let files = Self.resolveDroppedURLs(droppedURLs)
                guard !files.isEmpty else {
                    log.warning("[DropTarget] no valid file URLs in drop")
                    return false
                }
                log.debug("[DropTarget] using \(files.count) external URLs")
                return onDrop(files)
            } isTargeted: { targeted in
                onTargetChange(targeted)
            }
    }

    /// Resolve dropped URLs for external drags, or use internal draggedFiles.
    static func safeResolveURLs(_ urls: [URL], dragDropManager: DragDropManager) -> [CustomFile] {
        let internalFiles = dragDropManager.draggedFiles
        if !internalFiles.isEmpty { return internalFiles }
        return resolveDroppedURLs(urls)
    }

    /// Decode file URLs from NSItemProvider (external drag fallback).
    static func resolveDroppedURLs(_ urls: [URL]) -> [CustomFile] {
        urls.compactMap { url -> CustomFile? in
            guard url.isFileURL else { return nil }
            let path = url.standardizedFileURL.path
            guard !path.isEmpty, !path.contains("\0"),
                  FileManager.default.fileExists(atPath: path) else { return nil }
            return CustomFile(path: path)
        }
    }
}

// MARK: - Column Separator
/// Thin vertical blue line separator between columns (matches header dividers)
struct ColumnSeparator: View {
    var body: some View {
        Rectangle()
            .fill(ColumnSeparatorStyle.color)
            .frame(width: ColumnSeparatorStyle.width)
            .padding(.vertical, 2)
    }
}
