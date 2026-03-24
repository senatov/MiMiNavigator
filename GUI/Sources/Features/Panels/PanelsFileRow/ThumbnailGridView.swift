// ThumbnailGridView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Grid view for thumbnail mode.
//   - QLThumbnailGenerator for images, video frames, PDF pages
//   - SF Symbol icon fallback for all other file types
//   - File name + size shown below each cell
//   - Tappable cells with selection highlight
//   - Jump-to-edge buttons aligned with scrollbar

import AppKit
import FileModelKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ThumbnailGridView

struct ThumbnailGridView: View {

    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager

    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: FavPanelSide
    let cellSize: CGFloat
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void

    @State private var selectedIDs: Set<CustomFile.ID> = []

    /// Width matching the native scrollbar track (~15pt)
    private static let scrollbarWidth: CGFloat = 15

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cellSize, maximum: cellSize + 20), spacing: 8)]
    }

    private func handleSelection(for file: CustomFile, modifiers: NSEvent.ModifierFlags) {
        // ".." is navigation-only — never selectable
        guard !ParentDirectoryEntry.isParentEntry(file) else { return }

        if modifiers.contains(.command) {
            if selectedIDs.contains(file.id) {
                selectedIDs.remove(file.id)
            } else {
                selectedIDs.insert(file.id)
            }
            selectedID = selectedIDs.isEmpty ? nil : file.id
            onSelect(file)
            return
        }

        if modifiers.contains(.shift),
            let anchor = selectedID,
            let anchorIndex = files.firstIndex(where: { $0.id == anchor }),
            let targetIndex = files.firstIndex(where: { $0.id == file.id })
        {
            let lower = min(anchorIndex, targetIndex)
            let upper = max(anchorIndex, targetIndex)
            selectedIDs.removeAll()
            for item in files[lower...upper] where !ParentDirectoryEntry.isParentEntry(item) {
                selectedIDs.insert(item.id)
            }
            selectedID = file.id
            onSelect(file)
            return
        }
        selectedIDs = [file.id]
        selectedID = file.id
        onSelect(file)
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(files, id: \.id) { file in
                    ThumbnailCellView(
                        file: file,
                        cellSize: cellSize,
                        isSelected: selectedIDs.contains(file.id),
                        panelSide: panelSide,
                        dragFiles: dragFilesFor(file),
                        onSelect: { modifiers in
                            handleSelection(for: file, modifiers: modifiers)
                        },
                        onDoubleClick: { onDoubleClick(file) },
                        onFileAction: { action in
                            ContextMenuCoordinator.shared.handleFileAction(action, for: file, panel: panelSide, appState: appState)
                        },
                        onDirectoryAction: { action in
                            ContextMenuCoordinator.shared.handleDirectoryAction(
                                action, for: file, panel: panelSide, appState: appState)
                        }
                    )
                }
            }
            .padding(10)
        }
        // MARK: - Jump-to-edge buttons (matching file table style)
        .overlay(alignment: .trailing) {
            if files.count > 50 {
                VStack(spacing: 0) {
                    scrollEdgeButton(icon: "chevron.up.2") {
                        NotificationCenter.default.post(
                            name: .jumpToFirst,
                            object: panelSide
                        )
                    }
                    .help("Jump to top (Home)")

                    Spacer()

                    scrollEdgeButton(icon: "chevron.down.2") {
                        NotificationCenter.default.post(
                            name: .jumpToLast,
                            object: panelSide
                        )
                    }
                    .help("Jump to bottom (End)")
                }
                .frame(width: Self.scrollbarWidth)
            }
        }
    }

    // MARK: - Scroll Edge Button (3D square, matches scrollbar width)
    private func scrollEdgeButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.secondary)
                .frame(width: Self.scrollbarWidth, height: Self.scrollbarWidth)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(nsColor: .controlBackgroundColor).opacity(0.95),
                                    Color(nsColor: .controlBackgroundColor).opacity(0.75),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
                .shadow(color: .white.opacity(0.5), radius: 0.5, x: 0, y: -0.5)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Drag helpers
    private func dragFilesFor(_ file: CustomFile) -> [CustomFile] {
        if selectedIDs.contains(file.id) {
            return files.filter { selectedIDs.contains($0.id) }
        }
        return [file]
    }
}

// MARK: - ThumbnailCellView

private struct ThumbnailCellView: View {

    let file: CustomFile
    let cellSize: CGFloat
    let isSelected: Bool
    let panelSide: FavPanelSide
    let dragFiles: [CustomFile]
    let onSelect: (NSEvent.ModifierFlags) -> Void
    let onDoubleClick: () -> Void
    let onFileAction: (FileAction) -> Void
    let onDirectoryAction: (DirectoryAction) -> Void

    @State private var thumbnail: NSImage? = nil
    @State private var isHovered = false

    @Environment(AppState.self) private var appState
    @Environment(DragDropManager.self) private var dragDropManager

    private var imageSize: CGFloat { cellSize - 12 }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.18)
                            : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    )
                    .frame(width: cellSize, height: cellSize)

                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                } else {
                    fallbackIcon
                        .frame(width: imageSize, height: imageSize)
                }

                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: cellSize, height: cellSize)
                }
            }

            // Name — single line, macOS-style middle truncation
            Text(file.nameStr)
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: cellSize - 4)

            // Size
            if !file.isDirectory {
                Text(ByteCountFormatter.string(fromByteCount: file.sizeInBytes, countStyle: .file))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: cellSize)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onDoubleClick() }
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded {
                    let modifiers = NSApp.currentEvent?.modifierFlags ?? []
                    onSelect(modifiers)
                }
        )
        .contextMenu { contextMenuContent }
        .onDrag {
            dragDropManager.startDrag(files: dragFiles, from: panelSide)
            return makeDragProvider()
        } preview: {
            DragPreviewPopupView(files: dragFiles, panelSide: panelSide)
        }
        .task(id: file.pathStr) { await loadThumbnail() }
    }

    private func makeDragProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        if let first = dragFiles.first {
            provider.registerObject(first.urlValue as NSURL, visibility: .all)
        }
        let allDraggedPaths =
            dragFiles
            .map { $0.urlValue.absoluteString }
            .joined(separator: "\n")
        provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all) { completion in
            completion(allDraggedPaths.data(using: .utf8), nil)
            return nil
        }
        return provider
    }

    // MARK: - Context menu content
    @ViewBuilder
    private var contextMenuContent: some View {
        if file.isDirectory {
            DirectoryContextMenu(file: file, panelSide: panelSide) { action in
                onDirectoryAction(action)
            }
        } else {
            FileContextMenu(file: file, panelSide: panelSide) { action in
                onFileAction(action)
            }
        }
    }

    // MARK: - Fallback SF Symbol icon
    private var fallbackIcon: some View {
        Image(systemName: file.isDirectory ? "folder.fill" : sfSymbol(for: file.nameStr))
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(file.isDirectory ? .yellow : .secondary)
            .padding(12)
    }

    // MARK: - SF Symbol picker by extension
    private func sfSymbol(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
            case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff":
                return "photo"
            case "mp4", "mov", "avi", "mkv", "m4v", "wmv":
                return "film"
            case "mp3", "aac", "flac", "wav", "m4a", "ogg":
                return "music.note"
            case "pdf":
                return "doc.richtext"
            case "zip", "tar", "gz", "7z", "rar", "bz2":
                return "archivebox"
            case "swift", "py", "js", "ts", "java", "kt", "cpp", "c", "h", "m", "rb", "go", "rs":
                return "chevron.left.forwardslash.chevron.right"
            case "txt", "md", "rtf":
                return "doc.text"
            case "app":
                return "app.badge"
            default:
                return "doc"
        }
    }

    // MARK: - Thumbnail loading via QLThumbnailGenerator
    @MainActor
    private func loadThumbnail() async {
        if file.isDirectory { return }
        let url = file.urlValue
        let size = CGSize(width: imageSize * 2, height: imageSize * 2)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            self.thumbnail = rep.nsImage
        } catch {
            // Silently fall through to SF Symbol fallback
        }
    }
}
