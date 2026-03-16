    //
    //  FileRowMetadataColumnsView.swift
    //  MiMiNavigator
    //
    //  Extracted from FileRow for architectural separation.
    //  Responsible ONLY for rendering non-name metadata columns.
    //

    import SwiftUI
    import FileModelKit

    struct FileRowMetadataColumnsView: View {

        // MARK: - Dependencies

        let file: CustomFile
        let layout: ColumnLayoutModel
        let isParentEntry: Bool
        let colorStore: ColorThemeStore

        // MARK: - Derived Columns

        private var fixedColumns: [ColumnSpec] {
            layout.visibleColumns.filter { $0.id != .name }
        }

        // MARK: - Body

        var body: some View {
            ForEach(fixedColumns.indices, id: \.self) { index in
                let spec = fixedColumns[index]
                ColumnSeparator()
                metadataCell(for: spec)
            }
        }

        // MARK: - Cell Builder

        @ViewBuilder
        private func metadataCell(for spec: ColumnSpec) -> some View {
            cellText(for: spec.id)
                .font(metadataFont(for: spec.id))
                .foregroundStyle(cellColor(for: spec.id))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(
                    .leading,
                    spec.id == .owner
                        ? TableColumnDefaults.cellPadding + 1
                        : TableColumnDefaults.cellPadding
                )
                .padding(.trailing, TableColumnDefaults.cellPadding)
                .frame(
                    width: clampedColumnWidth(spec.width),
                    alignment: spec.id.alignment
                )
        }

        // MARK: - Formatting

        private func metadataFont(for column: ColumnID) -> Font {

            if column == .permissions {
                return .system(size: 11, design: .monospaced)
            }

            if column == .size || column == .childCount || isDateColumn(column) {
                return .system(size: 12).monospacedDigit()
            }

            return .system(size: 12)
        }

        private func isDateColumn(_ column: ColumnID) -> Bool {
            switch column {
                case .dateModified, .dateCreated, .dateLastOpened, .dateAdded:
                    return true
                default:
                    return false
            }
        }

        private func clampedColumnWidth(_ width: CGFloat) -> CGFloat {
            let minWidth: CGFloat = 24
            let maxWidth: CGFloat = 456
            return min(max(width, minWidth), maxWidth)
        }

        // MARK: - Cell Content

        @ViewBuilder
        private func cellText(for column: ColumnID) -> some View {
            switch column {

                case .dateModified:
                    Text(file.modifiedDateFormatted)

                case .size:
                    Text(SizeFormatter.format(file.sizeInBytes))

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
                    EmptyView()
            }
        }

        // MARK: - Coloring

        private func cellColor(for column: ColumnID) -> Color {

            if isParentEntry {
                return Color(nsColor: .systemGray).opacity(0.6)
            }

            if file.isHidden {
                return colorStore.activeTheme.hiddenFileColor
            }

            return column.columnColor(from: colorStore.activeTheme)
        }

        // MARK: - Local Size Formatter (decoupled from FileRow)
        private enum SizeFormatter {

            static func format(_ bytes: Int64) -> String {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
                formatter.countStyle = .file
                formatter.includesUnit = true
                return formatter.string(fromByteCount: bytes)
            }
        }
    }
