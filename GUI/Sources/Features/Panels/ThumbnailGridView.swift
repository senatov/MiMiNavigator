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

import AppKit
import FileModelKit
import QuickLookThumbnailing
import SwiftUI

// MARK: - ThumbnailGridView

struct ThumbnailGridView: View {

    @Environment(AppState.self) var appState

    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: PanelSide
    let cellSize: CGFloat
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cellSize, maximum: cellSize + 20), spacing: 8)]
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(files, id: \.id) { file in
                    ThumbnailCellView(
                        file: file,
                        cellSize: cellSize,
                        isSelected: selectedID == file.id,
                        onSelect: { onSelect(file) },
                        onDoubleClick: { onDoubleClick(file) }
                    )
                }
            }
            .padding(10)
        }
    }
}

// MARK: - ThumbnailCellView

private struct ThumbnailCellView: View {

    let file: CustomFile
    let cellSize: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onDoubleClick: () -> Void

    @State private var thumbnail: NSImage? = nil
    @State private var isHovered = false

    private var imageSize: CGFloat { cellSize - 12 }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail or icon
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected
                        ? Color.accentColor.opacity(0.18)
                        : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
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

                // Selection ring
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: cellSize, height: cellSize)
                }
            }

            // Name
            Text(file.nameStr)
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: cellSize - 4)
                .fixedSize(horizontal: false, vertical: true)

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
        .onTapGesture(count: 1) { onSelect() }
        .task(id: file.pathStr) { await loadThumbnail() }
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
        // Directories get no QL thumbnail
        if file.isDirectory { return }

        let url = file.urlValue
        let size = CGSize(width: imageSize * 2, height: imageSize * 2) // 2x for retina
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
            // Silently fall through to SF Symbol fallback — not every file has a QL provider
        }
    }
}
