    // FileRow.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 23.10.2024.
    //  Copyright © 2024-2026 Senatov. All rights reserved.

    import AppKit
    import FileModelKit
    import SwiftUI

import UniformTypeIdentifiers

// MARK: - Finder‑style icon cache

/// Global icon cache to avoid repeated NSWorkspace icon lookups.
/// NSWorkspace icon lookup is relatively expensive (filesystem + LaunchServices),
/// so caching dramatically improves performance in directories with many files.
@MainActor
final class FileIconCache {

    static let shared = FileIconCache()

    private var cache: [String: NSImage] = [:]

    /// Returns cached icon or loads it from the system.
    func icon(for path: String) -> NSImage {
        if let cached = cache[path] {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        cache[path] = icon
        return icon
    }

    /// Clears cache if memory pressure occurs or directory changes dramatically.
    func clear() {
        cache.removeAll()
    }
}

// MARK: - Async icon loader view

/// Loads file icon asynchronously to prevent UI blocking
/// when many rows appear simultaneously.
struct AsyncFileIconView: View {

    let file: CustomFile

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "doc")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .task(id: file.urlValue.path) {
            await loadIcon()
        }
    }

    private func loadIcon() async {
        let path = file.urlValue.path

        // Run lookup on main actor because NSWorkspace is AppKit
        let icon = await MainActor.run {
            FileIconCache.shared.icon(for: path)
        }

        self.icon = icon
    }
}

    // MARK: - Lightweight row view for file list with drag-drop support

    struct FileRow: View, Equatable {
        // MARK: - Equatable optimization
        /// Prevent SwiftUI from re-rendering the row unless the visible state actually changed.
        static func == (lhs: FileRow, rhs: FileRow) -> Bool {
            lhs.file.id == rhs.file.id &&
            lhs.isSelected == rhs.isSelected &&
            lhs.panelSide == rhs.panelSide
        }
        let index: Int
        let file: CustomFile
        let isSelected: Bool
        let panelSide: PanelSide
        let layout: ColumnLayoutModel
        let onSelect: (CustomFile) -> Void
        let onDoubleClick: (CustomFile) -> Void
        let onFileAction: (FileAction, CustomFile) -> Void
        let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
        let onMultiSelectionAction: (MultiSelectionAction) -> Void

        @Environment(AppState.self) var appState
        @Environment(DragDropManager.self) var dragDropManager

        @State private var colorStore = ColorThemeStore.shared
        @State private var isDropTargeted: Bool = false

        // MARK: - Selection colors — live from ColorThemeStore
        private var selectionActiveFill: Color { colorStore.activeTheme.selectionActive }
        private var selectionInactiveFill: Color { colorStore.activeTheme.selectionInactive }

        private static let dropTargetFill = Color.accentColor.opacity(0.2)
        private static let dropTargetBorder = Color.accentColor

        private var isActivePanel: Bool {
            appState.focusedPanel == panelSide
        }

        private var isParentEntry: Bool {
            ParentDirectoryEntry.isParentEntry(file)
        }

        private var isMarked: Bool {
            appState.isMarked(file, on: panelSide)
        }

        private var isValidDropTarget: Bool {
            file.isDirectory || file.isSymbolicDirectory
        }

        var body: some View {
            rowContainer
                .zIndex(isSelected ? 1 : 0)  // selected row renders above neighbours — border fully visible
        }

        // MARK: - Main Container
        private var rowContainer: some View {
            Group {
                if isParentEntry {
                    // ".." entry — simple, no drag-drop, no context menu
                    stableContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: FilePanelStyle.rowHeight)
                        .contentShape(Rectangle())
                        // tooltip removed — Get Info via context menu is sufficient
                        .simultaneousGesture(doubleTapGesture)
                        .simultaneousGesture(singleTapGesture)
                        .animation(nil, value: isSelected)
                } else {
                    // Normal file row — full drag-drop + context menu
                    stableContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: FilePanelStyle.rowHeight)
                        .contentShape(Rectangle())
                        // tooltip removed — Get Info via context menu is sufficient
                        .simultaneousGesture(doubleTapGesture)
                        .simultaneousGesture(singleTapGesture)
                        .animation(nil, value: isSelected)
                        .contextMenu { contextMenuContent }
                        // Drag is handled by DragOverlayView (AppKit NSDraggingSession)
                        // which supports true multi-file drag. SwiftUI .onDrag only
                        // supports one NSItemProvider = one file.
                        .modifier(
                            DropTargetModifier(
                                isValidTarget: isValidDropTarget,
                                isDropTargeted: $isDropTargeted,
                                onDrop: handleDrop,
                                onTargetChange: handleDropTargeting
                            ))
                }
            }
        }

        private var stableContent: some View {
            StableKeyView(
                file.id.hashValue ^ (isSelected ? 1 : 0) ^ (isActivePanel ? 2 : 0) ^ (isDropTargeted ? 4 : 0) ^ (isMarked ? 8 : 0)
            ) {
                ZStack(alignment: .leading) {
                    zebraBackground
                    highlightLayer
                    rowContent
                }
            }
        }

        private var doubleTapGesture: some Gesture {
            TapGesture(count: 2).onEnded { handleDoubleClick() }
        }

        private var singleTapGesture: some Gesture {
            TapGesture(count: 1).onEnded { handleSingleClick() }
        }

        // MARK: - Extracted Views
        private var zebraBackground: some View {
            if isParentEntry {
                // ".." row — fixed light grey background regardless of zebra index
                return AnyView(
                    Color(nsColor: .systemGray).opacity(0.13)
                        .allowsHitTesting(false))
            }
            if isActivePanel {
                // Active panel: warm white base with subtle zebra stripe
                let isOdd = index % 2 == 1
                return AnyView(
                    DesignTokens.warmWhite
                        .overlay(Color.black.opacity(isOdd ? 0.02 : 0))
                        .allowsHitTesting(false))
            }
            let zebraColors = NSColor.alternatingContentBackgroundColors
            return AnyView(
                Color(nsColor: zebraColors[index % zebraColors.count])
                    .allowsHitTesting(false))
        }

        @ViewBuilder
        private var highlightLayer: some View {
            if isDropTargeted && isValidDropTarget {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Self.dropTargetFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Self.dropTargetBorder, lineWidth: 2)
                    )
                    .padding(.horizontal, 4)
                    .allowsHitTesting(false)
            } else if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActivePanel ? selectionActiveFill : selectionInactiveFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .inset(by: 0.5)
                            .strokeBorder(Color(red: 0.18, green: 0.44, blue: 0.85).opacity(isActivePanel ? 0.75 : 0.35), lineWidth: 1)
                    )
                    .padding(.horizontal, 3)
                    .padding(.vertical, 0)
                    .allowsHitTesting(false)
            }
        }

        /// True when there are marked files on this panel (show group menu)
        private var hasMarkedFiles: Bool {
            appState.markedCount(for: panelSide) > 0
        }

        @ViewBuilder
        private var contextMenuContent: some View {
            if hasMarkedFiles {
                // Group context menu for marked files
                MultiSelectionContextMenu(
                    markedCount: appState.markedCount(for: panelSide),
                    panelSide: panelSide
                ) { action in
                    log.debug("[FileRow] multi-selection action=\(action.rawValue) count=\(appState.markedCount(for: panelSide))")
                    onMultiSelectionAction(action)
                }
            } else if file.isDirectory {
                DirectoryContextMenu(file: file, panelSide: panelSide) { action in
                    logContextMenuAction(action, isDirectory: true)
                    onDirectoryAction(action, file)
                }
            } else {
                FileContextMenu(file: file, panelSide: panelSide) { action in
                    logContextMenuAction(action, isDirectory: false)
                    onFileAction(action, file)
                }
            }
        }

        // MARK: - Event Handlers
        private func handleSingleClick() {
            // Detect modifier keys from current NSEvent
            let modifiers = Self.currentClickModifiers()
            log.debug("[FileRow] single-click on '\(file.nameStr)' panel=\(panelSide) modifiers=\(modifiers)")
            // Always select the file (updates cursor position)
            onSelect(file)

            // Handle multi-selection via modifier keys
            appState.handleClickWithModifiers(on: file, modifiers: modifiers)
        }

        /// Read modifier keys from the current NSEvent
        private static func currentClickModifiers() -> ClickModifiers {
            guard let event = NSApp.currentEvent else { return .none }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) {
                return .command
            } else if flags.contains(.shift) {
                return .shift
            }
            return .none
        }

        private func handleDoubleClick() {
            log.debug("[FileRow] double-click on '\(file.nameStr)' isDir=\(file.isDirectory)")
            onDoubleClick(file)
        }

        private func handleDropTargeting(_ targeted: Bool) {
            guard isValidDropTarget else { return }
            log.verbose("[FileRow] drop target '\(file.nameStr)' targeted=\(targeted)")
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTargeted = targeted
            }
            if targeted {
                dragDropManager.setDropTarget(file.urlValue)
            }
        }

        private func logContextMenuAction(_ action: Any, isDirectory: Bool) {
            let type = isDirectory ? "directory" : "file"
            log.debug("[FileRow] \(type) context menu action=\(action) file='\(file.nameStr)'")
        }

        // MARK: - Handle drop on this row (directory)
        private func handleDrop(_ droppedFiles: [CustomFile]) -> Bool {
            log.info("[FileRow] handleDrop on '\(file.nameStr)' validTarget=\(isValidDropTarget) droppedCount=\(droppedFiles.count)")
            guard isValidDropTarget else {
                log.warning("[FileRow] handleDrop rejected: not a valid drop target")
                return false
            }
            guard !droppedFiles.isEmpty else {
                log.warning("[FileRow] handleDrop rejected: no files dropped")
                return false
            }
            let droppedPaths = Set(droppedFiles.map { $0.urlValue.path })
            if droppedPaths.contains(file.urlValue.path) {
                log.warning("[FileRow] handleDrop rejected: cannot drop onto self")
                return false
            }
            log.info("[FileRow] handleDrop accepted: transferring \(droppedFiles.count) files to '\(file.nameStr)'")
            dragDropManager.prepareTransfer(files: droppedFiles, to: file.urlValue, from: panelSide)
            return true
        }

        // MARK: - Column colors - per-column accent when not selected, white when selected+active
        private func cellColor(for col: ColumnID) -> Color {
            if isParentEntry { return Color(nsColor: .systemGray).opacity(0.6) }
            if file.isHidden { return colorStore.activeTheme.hiddenFileColor }
            return col.columnColor(from: colorStore.activeTheme)
        }

        // MARK: - System font (Finder style)
        private var columnFont: Font {
            .system(size: 12)
        }

        // MARK: - Row content — driven by ColumnLayoutModel
        /// Column widths and separators must EXACTLY match TableHeaderView layout:
        ///   [Name flexible] | sep(1pt) | [col2 spec.width] | sep(1pt) | [col3 spec.width] | ...
        /// NO extra padding inside fixed columns — width IS the total width.
        private var rowContent: some View {
            let fixedCols = layout.visibleColumns.filter { $0.id != .name }
            return HStack(alignment: .center, spacing: 0) {
                // Name — flexible (matches header nameHeader)
                FileRowView(file: file, isSelected: isSelected, isActivePanel: isActivePanel, isMarked: isMarked)
                    .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)

                // Fixed columns — separator before each, width EXACT (no internal padding)
                ForEach(fixedCols.indices, id: \.self) { i in
                    let spec = fixedCols[i]
                    ColumnSeparator()
                    cellText(for: spec.id)
                        .font(
                            spec.id == .permissions
                                ? .system(size: 11, design: .monospaced)
                                : (spec.id == .size || spec.id == .childCount
                                    || [.dateModified, .dateCreated, .dateLastOpened, .dateAdded].contains(spec.id)
                                    ? columnFont.monospacedDigit()
                                    : columnFont)
                        )
                        .foregroundStyle(cellColor(for: spec.id))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, TableColumnDefaults.cellPadding)
                        .frame(width: spec.width, alignment: spec.id.alignment)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }

        @ViewBuilder
        private func cellText(for col: ColumnID) -> some View {
            switch col {
                case .name: EmptyView()
                case .dateModified: Text(file.modifiedDateFormatted)
                case .size: Text(file.fileSizeFormatted)
                case .kind: KindCell(file: file)
                case .permissions: PermissionsCell(permissions: file.permissionsFormatted)
                case .owner: Text(file.ownerFormatted)
                case .childCount: Text(file.childCountFormatted)
                case .dateCreated: Text(file.creationDateFormatted)
                case .dateLastOpened: Text(file.lastOpenedFormatted)
                case .dateAdded: Text(file.dateAddedFormatted)
                case .group: Text(file.groupNameFormatted)
            }
        }
    }

    // MARK: - Kind column cell
    /// HIG-26: folder outline weight .light, archive = icon+abbrev, alias = arrow
    private struct KindCell: View {
        let file: CustomFile

        var body: some View {
            if file.isDirectory || file.isSymbolicDirectory {
                Image(systemName: file.isSymbolicDirectory ? "folder.badge.questionmark" : "folder")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 12, weight: .light))
                    .help(file.isSymbolicDirectory ? "Symbolic Link to Folder" : "Folder")
            } else if file.isSymbolicLink {
                Image(systemName: "arrow.up.right.square")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 12, weight: .light))
                    .help("Symbolic Link")
            } else if file.isArchiveFile {
                HStack(spacing: 3) {
                    Image(systemName: archiveSymbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 12, weight: .regular))
                    Text(archiveAbbrev)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                }
                .help(fullKindDescription)
            } else {
                Text(shortKind)
                    .help(fullKindDescription)
            }
        }

        private var archiveAbbrev: String {
            let name = file.nameStr.lowercased()
            if name.hasSuffix(".tar.gz") { return "TGZ" }
            if name.hasSuffix(".tar.bz2") { return "TBZ2" }
            if name.hasSuffix(".tar.xz") { return "TXZ" }
            if name.hasSuffix(".tar.lzma") { return "TLZ" }
            if name.hasSuffix(".tar.zst") { return "TZS" }
            if name.hasSuffix(".tar.lz4") { return "TL4" }
            if name.hasSuffix(".tar.lzo") { return "TLO" }
            if name.hasSuffix(".tar.lz") { return "TLZ" }
            let ext = file.fileExtension.uppercased()
            if ext.count > 5 { return String(ext.prefix(4)) + "…" }
            return ext.isEmpty ? "ARC" : ext
        }

        /// SF Symbol for archive icon — colored by format family
        private var archiveSymbol: String {
            let ext = file.fileExtension.lowercased()
            let name = file.nameStr.lowercased()
            // disk images
            if ext == "dmg" || ext == "img" || ext == "iso" { return "internaldrive" }
            // java / android
            if ["jar", "war", "ear", "aar", "apk"].contains(ext) { return "archivebox.fill" }
            // modern compression (zst, lz4, xz, lzma)
            if ["zst", "zstd", "lz4", "xz", "lzma", "txz", "tlz"].contains(ext)
                || name.hasSuffix(".tar.xz") || name.hasSuffix(".tar.lzma")
                || name.hasSuffix(".tar.zst") || name.hasSuffix(".tar.lz4")
            {
                return "shippingbox"
            }
            // bzip2 family
            if ["bz2", "bzip2", "tbz", "tbz2"].contains(ext)
                || name.hasSuffix(".tar.bz2")
            {
                return "shippingbox.fill"
            }
            // gzip / tar.gz
            if ["gz", "tgz", "gzip", "tar"].contains(ext)
                || name.hasSuffix(".tar.gz")
            {
                return "cylinder"
            }
            // 7z
            if ext == "7z" { return "doc.zipper" }
            // zip (default)
            return "zipper.page"
        }

        private var shortKind: String {
            let ext = file.fileExtension.uppercased()
            if ext.isEmpty { return "Doc" }
            if let idx = ext.firstIndex(where: { $0 == "_" || $0 == "-" }) {
                return String(ext[..<idx])
            }
            if ext.count > 5 { return String(ext.prefix(4)) + "…" }
            return ext
        }

        private var fullKindDescription: String {
            let ext = file.fileExtension.lowercased()
            guard !ext.isEmpty else { return "Document" }
            if let uttype = UTType(filenameExtension: ext), let desc = uttype.localizedDescription {
                return desc
            }
            return ext.uppercased()
        }
    }

    private struct PermissionsCell: View {
        let permissions: String

        var body: some View {
            Text(permissions)
                .help(octalValue)
        }

        /// Convert symbolic permissions (rwxr-xr-x) to octal (755)
        private var octalValue: String {
            let chars = Array(permissions)
            guard chars.count >= 9 else { return permissions }
            // Take last 9 characters (skip type indicator like 'd' or '-')
            let permChars = chars.suffix(9)
            guard permChars.count == 9 else { return permissions }
            let arr = Array(permChars)
            let owner = tripletToOctal(arr[0], arr[1], arr[2])
            let group = tripletToOctal(arr[3], arr[4], arr[5])
            let other = tripletToOctal(arr[6], arr[7], arr[8])
            return "\(owner)\(group)\(other)"
        }

        /// Convert rwx triplet to octal digit (0-7)
        private func tripletToOctal(_ r: Character, _ w: Character, _ x: Character) -> Int {
            var value = 0
            if r == "r" { value += 4 }
            if w == "w" { value += 2 }
            if x == "x" || x == "s" || x == "t" { value += 1 }
            return value
        }
    }
