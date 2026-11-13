// ThumbnailGridView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Grid view for thumbnail mode.
//   - QLThumbnailGenerator for images, video frames, PDF pages
//   - System file icon fallback when no content thumbnail is available
//   - File name + size shown below each cell
//   - Tappable cells with selection highlight
//   - Jump-to-edge buttons aligned with scrollbar

import AppKit
import FileModelKit
import QuickLookThumbnailing
import RenameKit
import SwiftUI

// MARK: - ThumbnailGridView

struct ThumbnailGridView: View {

    @Environment(AppState.self) var appState
    @State private var hasScrollableContent = false
    @State private var nativeScrollView: NSScrollView?

    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let panelSide: FavPanelSide
    let cellSize: CGFloat
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void

    private let columnSpacing: CGFloat = 8

    private let horizontalPadding: CGFloat = 20

    private var markedIDs: Set<String> {
        appState.markedFiles(for: panelSide)
    }

    private func handleSelection(for file: CustomFile, modifiers: ClickModifiers) {
        guard !ParentDirectoryEntry.isParentEntry(file) else { return }
        selectedID = file.id
        onSelect(file)
        appState.handleClickWithModifiers(on: file, modifiers: modifiers)
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let metrics = ThumbnailGridMetrics(
                panelWidth: geometry.size.width,
                preferredSize: cellSize,
                horizontalPadding: horizontalPadding,
                columnSpacing: columnSpacing
            )
            PanelScrollView(hasScrollableContent: hasScrollableContent, onCapture: { nativeScrollView = $0 }) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(metrics.columnWidth), spacing: columnSpacing, alignment: .top), count: metrics.columnCount), alignment: .leading, spacing: 10) {
                    ForEach(files, id: \.id) { file in
                        ThumbnailCellView(
                            file: file,
                            cellSize: metrics.thumbnailSize,
                            cellWidth: metrics.columnWidth,
                            isSelected: selectedID == file.id || markedIDs.contains(file.id),
                            panelSide: panelSide,
                            onDoubleClick: { onDoubleClick(file) }
                        )
                        .anchorPreference(key: ThumbnailCellFramesKey.self, value: .bounds) { [file.id: $0] }
                    }
                }
                .frame(width: metrics.contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding / 2)
                .padding(.vertical, 10)
            }
            .onScrollGeometryChange(for: Bool.self) { $0.contentSize.height > $0.containerSize.height + 1 } action: { _, scrollable in
                hasScrollableContent = scrollable
            }
            .overlayPreferenceValue(ThumbnailCellFramesKey.self) { anchors in
                GeometryReader { proxy in
                    DragOverlayView(
                        panelSide: panelSide,
                        scrollView: nil,
                        rows: files,
                        gridFrames: anchors.mapValues { proxy[$0] },
                        onMouseDownFile: { file, modifiers in
                            handleSelection(for: file, modifiers: modifiers)
                        }
                    )
                }
            }
        }
        .overlay(alignment: .trailing) {
            ScrollBarJumpButtons(panelSide: panelSide, rowCount: files.count)
                .offset(x: ScrollBarConfig.thumbnailAlignmentInset)
        }
        .onReceive(NotificationCenter.default.publisher(for: .jumpToFirst)) { notification in
            if notification.object as? FavPanelSide == panelSide { scrollToEdge(top: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jumpToLast)) { notification in
            if notification.object as? FavPanelSide == panelSide { scrollToEdge(top: false) }
        }
    }

    // MARK: - Jump to Edge
    private func scrollToEdge(top: Bool) {
        guard let scrollView = nativeScrollView else { return }
        let clipView = scrollView.contentView
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        let targetY = top ? 0 : max(0, documentHeight - clipView.bounds.height)
        clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: targetY))
        scrollView.reflectScrolledClipView(clipView)
    }

}

// MARK: - Thumbnail Cell Frames
private struct ThumbnailCellFramesKey: PreferenceKey {
    static let defaultValue: [CustomFile.ID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CustomFile.ID: Anchor<CGRect>], nextValue: () -> [CustomFile.ID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - ThumbnailCellView

private struct ThumbnailCellView: View {
    @State private var preferences = UserPreferences.shared

    let file: CustomFile
    let cellSize: CGFloat
    let cellWidth: CGFloat
    let isSelected: Bool
    let panelSide: FavPanelSide
    let onDoubleClick: () -> Void

    @State private var thumbnail: NSImage? = nil
    @State private var creationDate: Date? = nil
    @State private var isHovered = false

    @Environment(AppState.self) private var appState

    private var imageSize: CGSize {
        let edge = max(1, cellSize - 8)
        guard let size = thumbnail?.size, size.width > 0, size.height > 0 else {
            return CGSize(width: edge, height: edge)
        }
        let scale = edge / max(size.width, size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

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
                    .frame(width: imageSize.width + 8, height: imageSize.height + 8)

                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: imageSize.width, height: imageSize.height)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                } else {
                    fallbackIcon
                        .frame(width: imageSize.width, height: imageSize.height)
                }

                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: imageSize.width + 8, height: imageSize.height + 8)
                }
            }

            // Selected files reveal the complete name without changing the image size.
            nameView

            // File metadata
            if !file.isDirectory {
                fileMetadata
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: cellWidth)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onDoubleClick() }
        .contextMenu {
            FileItemContextMenu(file: file, panelSide: panelSide)
        }
        .task(id: ThumbnailLoadID(path: file.pathStr, width: Int(cellSize.rounded()))) { await loadThumbnail() }
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
            Text(isSelected ? file.nameStr : compactName)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .lineLimit(isSelected ? nil : 1)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(width: cellWidth - 4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(file.nameStr)
        }
    }

    // MARK: - Compact filename
    private var compactName: String {
        let name = file.nameStr
        guard name.count > 36 else { return name }
        return String(name.prefix(22)) + "…" + String(name.suffix(13))
    }

    // MARK: - File metadata
    private var fileMetadata: Text {
        let size = PanelMetadataFormatter.size(file.sizeInBytes, format: preferences.snapshot.sizeFormat, alwaysKB: preferences.snapshot.showSizeInKB)
        guard let creationDate = file.creationDate ?? self.creationDate else {
            return Text("\(Image(systemName: "internaldrive")) \(size)")
        }
        let date = PanelMetadataFormatter.date(creationDate, format: preferences.snapshot.dateFormat)
        return Text("\(Image(systemName: "internaldrive")) \(size)  \(Image(systemName: "clock")) \(date)")
    }

    // MARK: - Commit Inline Rename
    private func commitInlineRename() {
        InlineRenameCommitter.commit(file: file, panel: panelSide, appState: appState)
    }

    // MARK: - Fallback system file icon
    private var fallbackIcon: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
            .resizable()
            .scaledToFit()
            .padding(12)
    }

    // MARK: - Thumbnail loading via QLThumbnailGenerator
    @MainActor
    private func loadThumbnail() async {
        thumbnail = nil
        creationDate = file.creationDate
        if file.isDirectory { return }
        let url = file.urlValue
        if creationDate == nil, url.isFileURL {
            creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        }
        let edge = max(1, cellSize - 8)
        let size = CGSize(width: edge, height: edge)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            guard !Task.isCancelled else { return }
            self.thumbnail = rep.nsImage
        } catch {
            guard VideoFramePreview.supports(url) else { return }
            let frame = await VideoFramePreview.image(for: url, edge: Int(edge * scale))
            guard !Task.isCancelled else { return }
            self.thumbnail = frame
        }
    }
}

// MARK: - ThumbnailLoadID

private struct ThumbnailLoadID: Hashable {
    let path: String
    let width: Int
}
