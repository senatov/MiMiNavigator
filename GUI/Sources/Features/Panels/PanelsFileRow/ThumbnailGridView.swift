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
import RenameKit
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

    /// Width matching the native scrollbar track — driven by ScrollBarConfig
    private static let scrollbarWidth: CGFloat = ScrollBarConfig.trackWidth

    @State private var columnSpans: [CustomFile.ID: Int] = [:]

    private let columnSpacing: CGFloat = 8

    private let horizontalPadding: CGFloat = 20

    private var markedIDs: Set<String> {
        appState.markedFiles(for: panelSide)
    }

    private func handleSelection(for file: CustomFile, modifiers: NSEvent.ModifierFlags) {
        guard !ParentDirectoryEntry.isParentEntry(file) else { return }
        selectedID = file.id
        onSelect(file)
        appState.handleClickWithModifiers(on: file, modifiers: clickModifiers(from: modifiers))
    }

    private func clickModifiers(from flags: NSEvent.ModifierFlags) -> ClickModifiers {
        if flags.contains(.command) { return .command }
        if flags.contains(.shift) { return .shift }
        return .none
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                AdaptiveThumbnailLayout(cellSize: cellSize, columnSpacing: columnSpacing, rowSpacing: 10) {
                    ForEach(files, id: \.id) { file in
                        let requestedSpan = columnSpans[file.id] ?? 1
                        let span = min(requestedSpan, columnCount(for: geometry.size.width))
                        ThumbnailCellView(
                            file: file,
                            cellSize: cellSize,
                            requestedColumnSpan: requestedSpan,
                            columnSpan: span,
                            columnSpacing: columnSpacing,
                            isSelected: selectedID == file.id || markedIDs.contains(file.id),
                            panelSide: panelSide,
                            dragFiles: dragFilesFor(file),
                            onSelect: { modifiers in
                                handleSelection(for: file, modifiers: modifiers)
                            },
                            onColumnSpanChange: { columnSpans[file.id] = $0 },
                            onDoubleClick: { onDoubleClick(file) }
                        )
                        .layoutValue(key: ThumbnailColumnSpanKey.self, value: span)
                    }
                }
                .padding(10)
            }
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

    // MARK: - Column Count

    private func columnCount(for width: CGFloat) -> Int {
        let contentWidth = max(0, width - horizontalPadding)
        return max(1, Int((contentWidth + columnSpacing) / (cellSize + columnSpacing)))
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
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.72), lineWidth: 0.75)
                )
                .compositingGroup()
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Drag helpers
    private func dragFilesFor(_ file: CustomFile) -> [CustomFile] {
        if markedIDs.contains(file.id) {
            return files.filter { markedIDs.contains($0.id) }
        }
        return [file]
    }
}

// MARK: - ThumbnailCellView

private struct ThumbnailCellView: View {

    let file: CustomFile
    let cellSize: CGFloat
    let requestedColumnSpan: Int
    let columnSpan: Int
    let columnSpacing: CGFloat
    let isSelected: Bool
    let panelSide: FavPanelSide
    let dragFiles: [CustomFile]
    let onSelect: (NSEvent.ModifierFlags) -> Void
    let onColumnSpanChange: (Int) -> Void
    let onDoubleClick: () -> Void

    @State private var thumbnail: NSImage? = nil
    @State private var isHovered = false

    @Environment(AppState.self) private var appState
    @Environment(DragDropManager.self) private var dragDropManager

    private var cellWidth: CGFloat {
        CGFloat(columnSpan) * cellSize + CGFloat(columnSpan - 1) * columnSpacing
    }

    private var imageWidth: CGFloat { cellWidth - 12 }

    private var imageHeight: CGFloat { cellSize - 12 }

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
                    .frame(width: cellWidth, height: cellSize)

                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: imageWidth, height: imageHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                } else {
                    fallbackIcon
                        .frame(width: imageWidth, height: imageHeight)
                }

                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: cellWidth, height: cellSize)
                }
            }

            // Name — single line, macOS-style middle truncation
            nameView

            // Size
            if !file.isDirectory {
                Text(ByteCountFormatter.string(fromByteCount: file.sizeInBytes, countStyle: .file))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: cellWidth)
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
        .contextMenu {
            FileItemContextMenu(file: file, panelSide: panelSide)
        }
        .onDrag {
            dragDropManager.startDrag(files: dragFiles, from: panelSide, appState: appState)
            return makeDragProvider()
        } preview: {
            DragPreviewPopupView(files: dragFiles, panelSide: panelSide)
        }
        .task(id: ThumbnailLoadID(path: file.pathStr, width: Int(imageWidth.rounded()))) { await loadThumbnail() }
    }

    // MARK: - Name View
    @ViewBuilder
    private var nameView: some View {
        if InlineRenameCommitter.isActive(file: file, panel: panelSide, appState: appState) {
            InlineRenameField(
                text: Bindable(appState.inlineRename).editedName,
                originalName: appState.inlineRename.originalName,
                nameWidth: cellWidth - 4,
                preservesExtension: !file.isDirectory,
                onCommit: { commitInlineRename() },
                onCancel: { appState.inlineRename.cancel() }
            )
            .font(.system(size: 11))
            .frame(width: cellWidth - 4)
        } else {
            Text(file.nameStr)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: cellWidth - 4)
        }
    }

    // MARK: - Commit Inline Rename
    private func commitInlineRename() {
        InlineRenameCommitter.commit(file: file, panel: panelSide, appState: appState)
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
        let sourceSpan = await Task.detached(priority: .utility) {
            ThumbnailAspectRatioReader.columnSpan(for: url)
        }.value
        if let sourceSpan, sourceSpan != requestedColumnSpan {
            onColumnSpanChange(sourceSpan)
            return
        }
        let size = CGSize(width: imageWidth, height: imageHeight)
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

// MARK: - ThumbnailLoadID

private struct ThumbnailLoadID: Hashable {
    let path: String
    let width: Int
}
