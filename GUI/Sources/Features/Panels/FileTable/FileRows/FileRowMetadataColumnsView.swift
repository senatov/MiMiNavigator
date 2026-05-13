// FileRowMetadataColumnsView.swift
// MiMiNavigator — Renders metadata columns (non-name) in file rows.
// Width driven by ColumnLayoutModel for pixel-perfect header alignment.

import FileModelKit
import SwiftUI

struct FileRowMetadataColumnsView: View {

    let file: CustomFile
    let layout: ColumnLayoutModel
    let isParentEntry: Bool
    let colorStore: ColorThemeStore

    private var fixedColumns: [ColumnSpec] {
        layout.visibleColumns.filter { $0.id != .name }
    }

    var body: some View {
        ForEach(fixedColumns.indices, id: \.self) { index in
            let spec = fixedColumns[index]
            dividerSpacer
            metadataCell(for: spec)
        }
    }

    // MARK: - Divider Spacer

    /// 14pt spacer matching header ResizableDivider width
    private var dividerSpacer: some View {
        return ZStack {
            Color.clear.frame(width: 14)
            Rectangle()
                .fill(ColorThemeStore.shared.activeTheme.dividerNormalColor)
                .frame(width: 1)
        }
        .frame(width: 14)
        .allowsHitTesting(false)
    }

    // MARK: - Cell

    @ViewBuilder
    private func metadataCell(for spec: ColumnSpec) -> some View {
        if spec.id.hasCustomView {
            // Kind & Permissions use SwiftUI views with icons — can't render in Canvas.
            // Standard truncation + clipped is acceptable for these short values.
            HStack(spacing: 0) {
                if spec.id.alignment == .trailing { Spacer(minLength: 0) }
                cellContent(for: spec.id)
                    .font(cellFont(for: spec.id))
                    .foregroundStyle(cellColor(for: spec.id))
                    .lineLimit(1)
                if spec.id.alignment == .leading { Spacer(minLength: 0) }
            }
            .padding(.leading, spec.id.contentPadding.leading)
            .padding(.trailing, spec.id.contentPadding.trailing)
            .frame(width: spec.width)
            .clipped()
        } else {
            // Canvas renders text via Core Graphics — no "…" truncation,
            // hard clip at canvas bounds. One draw call per cell, zero SwiftUI layout overhead.
            // Re-renders automatically when spec.width changes (Canvas is frame-dependent).
            Canvas { context, size in
                let text = cellText(for: spec.id)
                let resolved = context.resolve(
                    Text(text)
                        .font(cellFont(for: spec.id))
                        .foregroundStyle(cellColor(for: spec.id))
                )
                let textSize = resolved.measure(in: size)
                let x: CGFloat
                switch spec.id.alignment {
                case .trailing:
                    x = size.width - spec.id.contentPadding.trailing - textSize.width
                case .center:
                    x = (size.width - textSize.width) / 2
                default:
                    x = spec.id.contentPadding.leading
                }
                let y = (size.height - textSize.height) / 2
                context.draw(resolved, in: CGRect(x: x, y: y, width: textSize.width, height: textSize.height))
            }
            .frame(width: spec.width, height: FilePanelStyle.rowHeight)
        }
    }

    // MARK: - Cell Text (plain string for Canvas rendering)

    private func cellText(for column: ColumnID) -> String {
        switch column {
            case .dateModified: file.modifiedDateFormatted
            case .size: file.displaySizeFormatted
            case .kind: file.kindFormatted
            case .permissions: file.permissionsFormatted
            case .owner: file.ownerFormatted
            case .childCount: file.childCountFormatted
            case .dateCreated: file.creationDateFormatted
            case .dateLastOpened: file.lastOpenedFormatted
            case .dateAdded: file.dateAddedFormatted
            case .group: file.groupNameFormatted
            case .name: ""
        }
    }

    // MARK: - Cell Content (SwiftUI views — kept for backward compat, not used by Canvas)

    @ViewBuilder
    private func cellContent(for column: ColumnID) -> some View {
        switch column {
            case .dateModified: Text(file.modifiedDateFormatted)
            case .size: Text(file.displaySizeFormatted)
            case .kind: KindCell(file: file)
            case .permissions: PermissionsCell(permissions: file.permissionsFormatted)
            case .owner: Text(file.ownerFormatted)
            case .childCount: Text(file.childCountFormatted)
            case .dateCreated: Text(file.creationDateFormatted)
            case .dateLastOpened: Text(file.lastOpenedFormatted)
            case .dateAdded: Text(file.dateAddedFormatted)
            case .group: Text(file.groupNameFormatted)
            case .name: EmptyView()
        }
    }

    // MARK: - Cell Font

    private func cellFont(for column: ColumnID) -> Font {
        switch column {
            case .permissions:
                return .system(size: 11, design: .monospaced)
            case .size, .childCount, .dateModified, .dateCreated, .dateLastOpened, .dateAdded:
                return .system(size: 12).monospacedDigit()
            default:
                return .system(size: 12)
        }
    }

    // MARK: - Cell Color

    private func cellColor(for column: ColumnID) -> Color {
        if isParentEntry { return Color(nsColor: .systemGray).opacity(0.6) }
        if file.isHidden { return colorStore.activeTheme.hiddenFileColor }
        return column.columnColor(from: colorStore.activeTheme)
    }
}
