    // FileRow.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 23.10.2024.
    //  Copyright © 2024-2026 Senatov. All rights reserved.

    import AppKit
    import FileModelKit
    import SwiftUI
    import UniformTypeIdentifiers

    // MARK: - Lightweight row view for file list with drag-drop support
    @MainActor
    struct FileRow: View, Equatable {
        /// Shared formatter to avoid repeated ByteCountFormatter allocations during scrolling
        private static let sizeFormatter: ByteCountFormatter = {
            let f = ByteCountFormatter()
            f.countStyle = .file
            f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
            f.includesUnit = true
            // Avoid strings like "Zero KB" – use numeric form instead (e.g. "0 KB")
            f.allowsNonnumericFormatting = false
            return f
        }()
        /// Format size with consistent rules (avoid "0 KB")
        private static func formatSize(_ size: Int64) -> String {
            // DirectorySizeService uses a negative sentinel for "unavailable".
            if size < 0 { return "—" }
            if size == 0 { return "0 B" }
            return sizeFormatter.string(fromByteCount: size)
        }
        // MARK: - Equatable optimization
        /// Prevent SwiftUI from re-rendering the row unless the visible state actually changed.
        nonisolated static func == (lhs: FileRow, rhs: FileRow) -> Bool {
            lhs.file.id == rhs.file.id && lhs.isSelected == rhs.isSelected && lhs.panelSide == rhs.panelSide
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
        @State private var isHoveringParentRow: Bool = false

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
                    // ".." entry — behaves like a single interactive element (arrow + "..")
                    stableContent
                        .background(
                            isHoveringParentRow
                                ? Color.accentColor.opacity(0.08)
                                : Color.clear
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: FilePanelStyle.rowHeight)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.75, blendDuration: 0.1)) {
                                isHoveringParentRow = hovering
                            }

                            if hovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                        .simultaneousGesture(doubleTapGesture)
                        .simultaneousGesture(singleTapGesture)
                        .animation(.spring(response: 0.35, dampingFraction: 0.70), value: isHoveringParentRow)
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
        @ViewBuilder
        private var zebraBackground: some View {
            if isParentEntry {
                // ".." row — fixed light grey background regardless of zebra index
                Color(nsColor: .systemGray)
                    .opacity(0.13)
                    .allowsHitTesting(false)
            } else {
                let isOdd = index % 2 == 1
                if isActivePanel {
                    // Active panel: themed zebra (aged-paper by default)
                    (isOdd ? DesignTokens.zebraActiveOdd : DesignTokens.zebraActiveEven)
                        .allowsHitTesting(false)
                } else {
                    // Inactive panel: themed zebra (near-white by default)
                    (isOdd ? DesignTokens.zebraInactiveOdd : DesignTokens.zebraInactiveEven)
                        .allowsHitTesting(false)
                }
            }
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
                            .strokeBorder(
                                Color(#colorLiteral(red: 0.18, green: 0.44, blue: 0.85, alpha: 1)).opacity(isActivePanel ? 0.75 : 0.35),
                                lineWidth: 1)
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
        @ViewBuilder
        private var rowContent: some View {
            if isParentEntry {
                parentEntryContent()
            } else {
                normalRowContent()
            }
        }

        // MARK: - Parent entry renderer ("..")
        @ViewBuilder
        private func parentEntryContent() -> some View {
            FileRowView(
                file: file,
                isSelected: isSelected,
                isActivePanel: isActivePanel,
                isMarked: isMarked
            )
            .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }

        // MARK: - Normal file row renderer
        @ViewBuilder
        private func normalRowContent() -> some View {
            let fixedCols = layout.visibleColumns.filter { $0.id != .name }

            HStack(alignment: .center, spacing: 0) {
                nameColumnView()

                ForEach(fixedCols.indices, id: \.self) { i in
                    let spec = fixedCols[i]
                    ColumnSeparator()
                    metadataCell(for: spec)
                }
            }
        }

        // MARK: - Name column (flexible)
        @ViewBuilder
        private func nameColumnView() -> some View {
            FileRowView(
                file: file,
                isSelected: isSelected,
                isActivePanel: isActivePanel,
                isMarked: isMarked
            )
            .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)  // metadata columns must win width conflicts
            .clipped()
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }

        // MARK: - Metadata column cell helper
        @ViewBuilder
        private func metadataCell(for spec: ColumnSpec) -> some View {
            cellTextForMetadataColumn(spec.id)
                .font(metadataFont(for: spec.id))
                .foregroundStyle(cellColor(for: spec.id))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, spec.id == .owner ? TableColumnDefaults.cellPadding + 1 : TableColumnDefaults.cellPadding)
                .padding(.trailing, TableColumnDefaults.cellPadding)
                .frame(
                    width: clampedColumnWidth(spec.width),
                    alignment: spec.id.alignment
                )
        }

        // MARK: - Column rendering helpers
        private func metadataFont(for col: ColumnID) -> Font {
            if col == .permissions {
                return .system(size: 11, design: .monospaced)
            }

            if col == .size || col == .childCount || isDateColumn(col) {
                return columnFont.monospacedDigit()
            }

            return columnFont
        }

        private func isDateColumn(_ col: ColumnID) -> Bool {
            switch col {
                case .dateModified, .dateCreated, .dateLastOpened, .dateAdded:
                    return true
                default:
                    return false
            }
        }

        private func clampedColumnWidth(_ width: CGFloat) -> CGFloat {
            // Minimum width ≈ 3 characters (roughly 24 px in 12pt system font)
            let minWidth: CGFloat = 24

            // Maximum allowed width (design constraint)
            let maxWidth: CGFloat = 456  // 450 + ~6px visual padding

            return min(max(width, minWidth), maxWidth)
        }

        @ViewBuilder
        private func cellTextForMetadataColumn(_ col: ColumnID) -> some View {
            // Name column is rendered separately in `nameColumnView()`.
            if col == .name {
                EmptyView()
            } else {
                cellText(for: col)
            }
        }

        @ViewBuilder
        private func cellText(for col: ColumnID) -> some View {
            switch col {
                case .dateModified:
                    Text(file.modifiedDateFormatted)
                case .size:
                    sizeColumnView()
                case .kind:
                    KindCell(file: file)
                case .permissions:
                    PermissionsCell(permissions: file.permissionsFormatted)
                case .owner:
                    Text(file.ownerFormatted)
                case .childCount:
                    Text(file.childCountFormatted)
                case .dateCreated:
                    Text(file.creationDateFormatted)
                case .dateLastOpened:
                    Text(file.lastOpenedFormatted)
                case .dateAdded:
                    Text(file.dateAddedFormatted)
                case .group:
                    Text(file.groupNameFormatted)
                case .name:
                    // Kept for exhaustiveness; should never be hit.
                    EmptyView()
            }
        }

        // MARK: - Size column renderer
        @ViewBuilder
        private func sizeColumnView() -> some View {
            if isParentEntry {
                EmptyView()
            } else if file.isSymbolicLink && !file.isSymbolicDirectory {
                symlinkFileSizeView()
            } else if file.isDirectory || file.isSymbolicDirectory {
                directorySizeView()
            } else {
                Text(file.fileSizeFormatted)
            }
        }

        // MARK: - Reusable spinner for size calculation
        private var sizeSpinner: some View {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.6)
                .opacity(0.5)
                .frame(width: 8, height: 8)
        }

        // MARK: - Shared async task attachment for size cells
        private struct SizeTaskModifier: ViewModifier {
            let id: AnyHashable
            let shouldResetOnDisappear: Bool
            let reset: () -> Void
            let work: () async -> Void

            func body(content: Content) -> some View {
                content
                    .task(id: id, priority: .utility) {
                        await work()
                    }
                    .onDisappear {
                        guard shouldResetOnDisappear else { return }
                        reset()
                    }
            }
        }

        private func attachSizeTask(
            id: AnyHashable,
            shouldResetOnDisappear: Bool,
            reset: @escaping () -> Void,
            work: @escaping () async -> Void
        ) -> some ViewModifier {
            SizeTaskModifier(
                id: id,
                shouldResetOnDisappear: shouldResetOnDisappear,
                reset: reset,
                work: work
            )
        }

        // MARK: - Symlink file size
        @ViewBuilder
        private func symlinkFileSizeView() -> some View {
            Group {
                if let size = file.cachedAppSize, file.sizeIsExact {
                    Text(Self.formatSize(size))
                        .foregroundStyle(.secondary)
                } else {
                    sizeSpinner
                }
            }
            .modifier(
                attachSizeTask(
                    id: file.id,
                    shouldResetOnDisappear: !file.sizeIsExact,
                    reset: { file.sizeCalculationStarted = false },
                    work: { await runSymlinkSizeTask() }
                )
            )
        }

        // MARK: - Directory size view
        @ViewBuilder
        private func directorySizeView() -> some View {
            Group {
                if let size = file.cachedAppSize {
                    // If size is unavailable, show a dash. Keep it non-exact so it may retry later.
                    if size == DirectorySizeService.unavailableSize {
                        Text("—")
                            .foregroundStyle(.secondary)
                    } else if file.sizeIsExact {
                        Text(Self.formatSize(size))
                    } else if let shallow = file.cachedShallowSize {
                        Text("~" + Self.formatSize(shallow))
                            .foregroundStyle(.secondary)
                    } else {
                        sizeSpinner
                    }
                } else if let shallow = file.cachedShallowSize {
                    Text("~" + Self.formatSize(shallow))
                        .foregroundStyle(.secondary)
                } else {
                    sizeSpinner
                }
            }
            .modifier(
                attachSizeTask(
                    id: file.id,
                    shouldResetOnDisappear: !file.sizeIsExact,
                    reset: { file.sizeCalculationStarted = false },
                    work: { await runDirectorySizeTask() }
                )
            )
        }

        // MARK: - Symlink size calculation
        private func runSymlinkSizeTask() async {

            log.info("[FileRow] Task started for symlink file '\(file.nameStr)'")

            if file.sizeCalculationStarted {
                log.info("[FileRow] Skip - already started for symlink '\(file.nameStr)'")
                return
            }

            file.sizeCalculationStarted = true

            let resolved = file.urlValue.resolvingSymlinksInPath()

            if let attrs = try? FileManager.default.attributesOfItem(atPath: resolved.path),
                let fileSize = attrs[.size] as? NSNumber
            {

                file.cachedAppSize = fileSize.int64Value
                file.sizeIsExact = true
                file.sizeCalculationStarted = false

                log.info("[FileRow] Symlink file '\(file.nameStr)' size=\(fileSize.int64Value)")
            }
        }

        // MARK: - Normalize URL for size calculations
        private func normalizedURLForSize(_ url: URL) -> URL {
            // Canonicalize paths like /tmp <-> /private/tmp to avoid cache misses / duplicate work.
            url.resolvingSymlinksInPath().standardizedFileURL
        }

        // MARK: - Heuristics for virtual / cloud directories
        private func hasNonZeroChildCountHint() -> Bool {
            let raw = file.childCountFormatted.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty, raw != "0", raw != "-" else { return false }
            return true
        }

        // MARK: - Phase 1 helper: bounded-time estimate
        private func shallowSizeWithTimeout(url: URL, timeoutMs: UInt64) async -> Int64? {
            let target = normalizedURLForSize(url)

            return await withTaskGroup(of: Int64?.self) { group in
                group.addTask(priority: .utility) {
                    let value = await DirectorySizeService.shared.shallowSize(for: target)
                    return value
                }

                group.addTask {
                    try? await Task.sleep(nanoseconds: timeoutMs * 1_000_000)
                    return nil
                }

                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
        }

        // MARK: - Safety: do not treat zero as exact unless directory content is truly zero-sized
        private func isTrulyEmptyDirectory(_ url: URL) -> Bool {
            let target = normalizedURLForSize(url)
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: target,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsPackageDescendants]
            ) else {
                return false
            }
            for case let fileURL as URL in enumerator {
                if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                   vals.isDirectory != true,
                   let size = vals.fileSize, size > 0 {
                    return false
                }
            }
            return true
        }

        private func isLikelyVirtualDirectory(_ url: URL) -> Bool {
            let p = url.path
            // Cloud providers / virtual FS often report 0 for recursive size.
            if p.contains("/Library/CloudStorage/") { return true }
            if p.contains("/Library/Mobile Documents/") { return true }  // iCloud Drive
            if p.contains("OneDrive") { return true }
            if p.contains("ProtonDrive") { return true }
            return false
        }

        // MARK: - Directory size task orchestration
        private func runDirectorySizeTask() async {
            log.info(
                "[FileRow] Task started for directory '\(file.nameStr)' symDir=\(file.isSymbolicDirectory)")

            if file.sizeIsExact { return }

            // Reset guard when nothing is cached yet.
            if file.cachedAppSize == nil && file.cachedShallowSize == nil {
                file.sizeCalculationStarted = false
            }

            guard !file.sizeCalculationStarted else {
                log.info("[FileRow] Skip - already started for '\(file.nameStr)'")
                return
            }

            file.sizeCalculationStarted = true
            let targetURL = normalizedURLForSize(file.urlValue)

            // Phase 1 is best-effort and must never block Phase 2.
            await withTaskGroup(of: Void.self) { group in
                group.addTask(priority: .utility) { [fileName = file.nameStr] in
                    await performPhase1Shallow(for: targetURL)
                    log.verbose("[FileRow] Phase 1 task finished for '\(fileName)'")
                }

                group.addTask(priority: .utility) { [fileName = file.nameStr] in
                    await performPhase2FullSize(for: targetURL)
                    log.verbose("[FileRow] Phase 2 task finished for '\(fileName)'")
                }

                for await _ in group {}
            }
        }

        // MARK: - Phase 1: shallow directory size (fast estimate)
        private func performPhase1Shallow(for url: URL) async {
            log.info("[FileRow] Phase 1 (estimate): shallow size for '\(file.nameStr)' url='\(url.path)'")

            if file.cachedShallowSize != nil { return }
            if file.sizeIsExact { return }

            // Keep UI responsive: shallow estimate has a hard timeout.
            let timeoutMs: UInt64 = 120
            let shallowOpt = await shallowSizeWithTimeout(url: url, timeoutMs: timeoutMs)

            if Task.isCancelled {
                log.info("[FileRow] Phase 1 cancelled for '\(file.nameStr)'")
                file.sizeCalculationStarted = false
                return
            }

            guard let shallow = shallowOpt else {
                log.info("[FileRow] Phase 1 skipped for '\(file.nameStr)' (timeout=\(timeoutMs)ms)")
                return
            }

            // Avoid misleading "~0 B" when directory likely contains something.
            if shallow == 0, hasNonZeroChildCountHint() || file.isSymbolicDirectory || isLikelyVirtualDirectory(url) {
                log.info("[FileRow] Phase 1 produced 0 for '\(file.nameStr)' but looks non-empty — not showing estimate")
                return
            }

            file.cachedShallowSize = shallow
            log.info("[FileRow] Phase 1 complete (estimate): '\(file.nameStr)' shallow=\(shallow)")
        }

        // MARK: - Phase 2: full recursive directory size
        private func performPhase2FullSize(for url: URL) async {
            log.info("[FileRow] Phase 2: full size for '\(file.nameStr)' url='\(url.path)'")

            let size = await DirectorySizeService.shared.requestSize(for: url)

            if Task.isCancelled {
                log.info("[FileRow] Phase 2 cancelled for '\(file.nameStr)'")
                file.sizeCalculationStarted = false
                return
            }

            // If the service couldn't read/enumerate the directory, do not pretend it's "0 B".
            // Try a fallback scan only when we have evidence the directory is non-empty.
            if size == DirectorySizeService.unavailableSize {
                let shouldFallback = hasNonZeroChildCountHint() || file.isSymbolicDirectory || isLikelyVirtualDirectory(url)
                if shouldFallback {
                    log.warning(
                        "[FileRow] Phase 2 unavailable for '\(file.nameStr)' (childHint=\(hasNonZeroChildCountHint()), symDir=\(file.isSymbolicDirectory)) — running fallback scan"
                    )
                    let fallback = await fallbackDirectoryScanAsync(url: url)
                    log.warning("[FileRow] Fallback size for '\(file.nameStr)' -> \(fallback)")

                    // Treat fallback > 0 as exact, otherwise keep non-exact.
                    file.cachedAppSize = fallback
                    file.sizeIsExact = fallback > 0 ? true : false
                    file.sizeCalculationStarted = false

                    log.info("[FileRow] Phase 2 complete (fallback): '\(file.nameStr)' size=\(fallback)")
                    return
                } else {
                    log.warning("[FileRow] Phase 2 unavailable for '\(file.nameStr)' — keeping non-exact")
                    file.cachedAppSize = DirectorySizeService.unavailableSize
                    file.sizeIsExact = false
                    file.sizeCalculationStarted = false
                    return
                }
            }

            let finalSize = await resolveZeroSizeIfNeeded(size, url: url)

            // Treat persistent zero as suspicious for virtual dirs: keep non-exact so it can retry later.
            if finalSize == 0 {
                let looksVirtual = file.isSymbolicDirectory || isLikelyVirtualDirectory(url)
                let provenEmpty = isTrulyEmptyDirectory(url)

                // If we cannot prove emptiness (or it looks virtual), keep non-exact so it can retry later.
                if looksVirtual || !provenEmpty {
                    log.warning(
                        "[FileRow] Phase 2 produced 0 for '\(file.nameStr)' (virtual=\(looksVirtual), provenEmpty=\(provenEmpty)) — keeping non-exact"
                    )
                    file.cachedAppSize = 0
                    file.sizeIsExact = false
                    file.sizeCalculationStarted = false
                    return
                }
            }

            file.cachedAppSize = finalSize
            file.sizeIsExact = true
            file.sizeCalculationStarted = false

            log.info("[FileRow] Phase 2 complete: '\(file.nameStr)' size=\(finalSize)")
        }

        // MARK: - Handle suspicious zero results
        // Some macOS cloud or virtual directories (iCloud, OneDrive, FUSE mounts)
        // occasionally report size = 0 even when files exist.
        // If we get a suspicious 0, run a local fallback enumeration.
        private func resolveZeroSizeIfNeeded(_ size: Int64, url: URL) async -> Int64 {
            // Never treat "unavailable" as 0.
            if size == DirectorySizeService.unavailableSize { return size }
            guard size == 0 else { return size }

            let shallow = file.cachedShallowSize ?? 0
            let shouldFallback = (shallow > 0) || hasNonZeroChildCountHint() || file.isSymbolicDirectory || isLikelyVirtualDirectory(url)
            guard shouldFallback else {
                // Normal directory can legitimately be empty.
                return 0
            }

            log.warning(
                "[FileRow] Phase2 returned 0 for '\(file.nameStr)' (shallow=\(shallow), childHint=\(hasNonZeroChildCountHint()), symDir=\(file.isSymbolicDirectory)) — running fallback scan"
            )

            let fallback = await fallbackDirectoryScanAsync(url: url)

            log.warning("[FileRow] Fallback size for '\(file.nameStr)' -> \(fallback)")

            return fallback
        }

        // Slow but reliable directory enumeration.
        // Used only when DirectorySizeService returned an obviously wrong value.
        // MARK: - Fallback directory scan
        private func fallbackDirectoryScanAsync(url: URL) async -> Int64 {
            let target = normalizedURLForSize(url)
            return
                await Task.detached(priority: .utility) {
                    let fm = FileManager.default
                    var total: Int64 = 0

                    let keys: Set<URLResourceKey> = [
                        .isDirectoryKey,
                        .fileSizeKey,
                        .fileAllocatedSizeKey,
                        .totalFileAllocatedSizeKey,
                    ]

                    if let enumerator = fm.enumerator(
                        at: target,
                        includingPropertiesForKeys: Array(keys),
                        options: [.skipsPackageDescendants]
                    ) {
                        while let next = enumerator.nextObject() as? URL {
                            if let values = try? next.resourceValues(forKeys: keys) {
                                // Prefer allocated size when available.
                                if let alloc = values.totalFileAllocatedSize {
                                    total += Int64(alloc)
                                } else if let alloc = values.fileAllocatedSize {
                                    total += Int64(alloc)
                                } else if let s = values.fileSize {
                                    total += Int64(s)
                                }
                            }
                        }
                    }

                    return total
                }
                .value
        }
    }
