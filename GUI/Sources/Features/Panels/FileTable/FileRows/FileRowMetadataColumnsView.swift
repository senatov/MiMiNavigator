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
                .fill(ColumnSeparatorStyle.color)
                .frame(width: 1)
        }
        .frame(width: 14)
        .allowsHitTesting(false)
    }

    // MARK: - Cell

    @ViewBuilder
    private func metadataCell(for spec: ColumnSpec) -> some View {
        cellContent(for: spec.id)
            .font(cellFont(for: spec.id))
            .foregroundStyle(cellColor(for: spec.id))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, TableColumnDefaults.cellPadding)
            .frame(width: spec.width, alignment: spec.id.alignment)
    }

    // MARK: - Cell Content

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
