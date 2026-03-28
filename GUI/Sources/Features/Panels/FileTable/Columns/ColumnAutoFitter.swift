// ColumnAutoFitter.swift
// MiMiNavigator
//
// Created by Claude on 24.03.2026.
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FileModelKit
import SwiftUI


enum ColumnAutoFitter {

    private struct FittedColumn {
        let id: ColumnID
        var width: CGFloat
    }

    private static let dividerWidth: CGFloat = 14
    private static let minNameWidth: CGFloat = 120
    private static let maxNameWidthRatio: CGFloat = 0.8
    private static let emptyColumnWidth: CGFloat = 24
    private static let measuredContentInset: CGFloat = 5
    private static let trailingPanelInset: CGFloat = 17
    private static let ownerColumnInsetBoost: CGFloat = 8
    private static let widthStabilityEpsilon: CGFloat = 1
    private static let edgeAlignmentEpsilon: CGFloat = 0.5
    private static let correctiveClippingThreshold: CGFloat = 0.15


    static func autoFitAll(layout: ColumnLayoutModel, files: [CustomFile]) {
        guard let result = makeAutoFitResult(layout: layout, files: files) else { return }
        guard needsUpdate(layout: layout, fittedColumns: result.fittedColumns, nameWidth: result.nameWidth) else { return }

        apply(fittedColumns: result.fittedColumns, nameWidth: result.nameWidth, to: layout)
        logAutoFit(layout: layout, fittedColumns: result.fittedColumns, nameWidth: result.nameWidth)
    }

    private struct AutoFitResult {
        let fittedColumns: [FittedColumn]
        let nameWidth: CGFloat
    }

    private static func makeAutoFitResult(layout: ColumnLayoutModel, files: [CustomFile]) -> AutoFitResult? {
        guard shouldAutoFit(layout: layout, files: files) else { return nil }

        let visibleFixedColumns = layout.fixedColumns
        let dividerTotal = totalDividerWidth(for: visibleFixedColumns.count)
        var fittedColumns = measuredFixedWidths(for: visibleFixedColumns, files: files)
        var nameWidth = finalizedNameWidth(containerWidth: layout.containerWidth, fittedColumns: &fittedColumns, dividerTotal: dividerTotal)

        let columnTitles = visibleFixedColumns.map { $0.id.title }.joined(separator: ", ")
        log.debug("[AutoFit] pass=1")
        log.debug("[AutoFit] panel=\(Int(layout.containerWidth)) fixed=\(Int(totalFixedWidth(fittedColumns))) name=\(Int(nameWidth))")
        log.debug("[AutoFit] columns=\(columnTitles)")

        for passIndex in 2...3 {
            let requiresCorrection = needsCorrectivePass(
                columns: visibleFixedColumns,
                fittedColumns: fittedColumns,
                files: files,
                containerWidth: layout.containerWidth,
                nameWidth: nameWidth,
                dividerTotal: dividerTotal
            )

            guard requiresCorrection else {
                log.debug("[AutoFit] pass=\(passIndex) skipped")
                log.debug("[AutoFit] stable after pass=\(passIndex - 1)")
                break
            }

            applyCorrectivePass(columns: visibleFixedColumns, fittedColumns: &fittedColumns, files: files)
            nameWidth = finalizedNameWidth(containerWidth: layout.containerWidth, fittedColumns: &fittedColumns, dividerTotal: dividerTotal)
            log.debug("[AutoFit] pass=\(passIndex)")
            log.debug("[AutoFit] fixed=\(Int(totalFixedWidth(fittedColumns))) name=\(Int(nameWidth))")
        }

        return AutoFitResult(fittedColumns: fittedColumns, nameWidth: nameWidth)
    }

    private static func shouldAutoFit(layout: ColumnLayoutModel, files: [CustomFile]) -> Bool {
        layout.containerWidth > 0 && !files.isEmpty && !layout.fixedColumns.isEmpty
    }

    private static func logAutoFit(layout: ColumnLayoutModel, fittedColumns: [FittedColumn], nameWidth: CGFloat) {
        let detail = fittedColumns.map { "\($0.id.title)=\(Int($0.width))" }.joined(separator: " ")
        log.debug("[AutoFit] panelWidth=\(Int(layout.containerWidth)) name=\(Int(nameWidth)) trailingInset=\(Int(trailingPanelInset)) \(detail)")
    }


    private static func contentWidth(for col: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(col, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else {
            // Size column: use reference width ("999,99 MB") instead of collapsing to 24pt
            if col == .size {
                let fallback = ColumnWidthPolicy.sizeColumnFallbackWidth()
                log.debug("[AutoFit] column=\(col.title) no data yet, fallback=\(pt(fallback))")
                return fallback
            }
            log.debug("[AutoFit] column=\(col.title) no meaningful content, width=\(pt(emptyColumnWidth))")
            return emptyColumnWidth
        }

        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let weightedWidth = weightedAverageMeasuredWidth(measuredWidths)
        let fittedWidth = fittedContentWidth(for: col, measuredWidths: measuredWidths)
        let clampedWidth = fittedWidth.clamped(to: emptyColumnWidth...ColumnWidthPolicy.effectiveMaxWidth(for: col))

        log.debug("[AutoFit] column=\(col.title)")
        log.debug("[AutoFit] weightedAvg=\(pt(weightedWidth)) autoFit=\(pt(clampedWidth))")
        log.debug("[AutoFit] raw=\(pt(fittedWidth)) max=\(pt(col.maxWidth)) samples=\(measuredWidths.count)")

        return clampedWidth
    }

    private static func fittedContentWidth(for column: ColumnID, measuredWidths: [CGFloat]) -> CGFloat {
        switch column {
        case .owner:
            ownerContentWidth(measuredWidths)
        default:
            weightedAverageContentWidth(measuredWidths, for: column)
        }
    }

    private static func measuredTextWidths(_ texts: [String], font: NSFont) -> [CGFloat] {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return texts.map { ($0 as NSString).size(withAttributes: attributes).width }
    }

    private static func weightedAverageMeasuredWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        guard !measuredWidths.isEmpty else { return .zero }
        return measuredWidths.reduce(0, +) / CGFloat(measuredWidths.count)
    }

    private static func weightedAverageContentWidth(_ measuredWidths: [CGFloat], for column: ColumnID) -> CGFloat {
        let averageWidth = measuredWidths.reduce(0, +) / CGFloat(measuredWidths.count)
        let extraWidth = ColumnWidthPolicy.extraReserveWidth(for: column)
        return ceil(averageWidth + 2 * measuredContentInset + extraWidth)
    }



    private static func ownerContentWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        guard let maximumWidth = measuredWidths.max() else { return emptyColumnWidth }
        return ceil(maximumWidth + 2 * measuredContentInset + ownerColumnInsetBoost)
    }

    private static func measuredFixedWidths(for columns: [ColumnSpec], files: [CustomFile]) -> [FittedColumn] {
        var fittedColumns: [FittedColumn] = []

        for spec in columns.reversed() {
            let measuredWidth = contentWidth(for: spec.id, files: files)
            fittedColumns.append(FittedColumn(id: spec.id, width: measuredWidth))
        }

        return fittedColumns.reversed()
    }

    private static func finalizedNameWidth(containerWidth: CGFloat, fittedColumns: inout [FittedColumn], dividerTotal: CGFloat) -> CGFloat {
        var nameWidth = proposedNameWidth(containerWidth: containerWidth, fittedColumns: fittedColumns, dividerTotal: dividerTotal)

        if nameWidth < minNameWidth {
            reclaimWidthFromRightColumns(fittedColumns: &fittedColumns, requiredWidth: minNameWidth - nameWidth)
            nameWidth = proposedNameWidth(containerWidth: containerWidth, fittedColumns: fittedColumns, dividerTotal: dividerTotal)
        }

        nameWidth = max(minNameWidth, min(maxNameWidth(for: containerWidth), nameWidth))
        alignTrailingEdge(fittedColumns: &fittedColumns, containerWidth: containerWidth, nameWidth: nameWidth, dividerTotal: dividerTotal)
        return nameWidth
    }

    private static func maxNameWidth(for containerWidth: CGFloat) -> CGFloat {
        floor(containerWidth * maxNameWidthRatio)
    }

    private static func needsCorrectivePass(
        columns: [ColumnSpec],
        fittedColumns: [FittedColumn],
        files: [CustomFile],
        containerWidth: CGFloat,
        nameWidth: CGFloat,
        dividerTotal: CGFloat
    ) -> Bool {
        let effectivePanelWidth = nameWidth + totalFixedWidth(fittedColumns) + dividerTotal + trailingPanelInset
        if effectivePanelWidth > containerWidth + edgeAlignmentEpsilon {
            log.debug("[AutoFit] corrective pass requested: panel overflow effective=\(Int(effectivePanelWidth)) container=\(Int(containerWidth))")
            return true
        }

        for column in columns {
            guard let fittedColumn = fittedColumns.first(where: { $0.id == column.id }) else { continue }
            let clippingRatio = measuredClippingRatio(for: column.id, files: files, fittedWidth: fittedColumn.width)
            if clippingRatio > correctiveClippingThreshold {
                log.debug("[AutoFit] corrective pass requested: column=\(column.id.title) clipped=\(Int(clippingRatio * 100))% width=\(Int(fittedColumn.width))")
                return true
            }
        }

        return false
    }

    private static func applyCorrectivePass(columns: [ColumnSpec], fittedColumns: inout [FittedColumn], files: [CustomFile]) {
        log.debug("[AutoFit] corrective pass started columns=\(fittedColumns.count) files=\(files.count)")

        for index in fittedColumns.indices {
            let columnID = fittedColumns[index].id
            guard columns.contains(where: { $0.id == columnID }) else { continue }

            let oldWidth = fittedColumns[index].width
            let correctiveWidth = correctiveContentWidth(for: columnID, files: files)
            guard correctiveWidth > oldWidth else {
                log.debug("[AutoFit] corrective keep column=\(columnID.title) width=\(Int(oldWidth))")
                continue
            }

            let newWidth = min(correctiveWidth, columnID.maxWidth)
            fittedColumns[index].width = newWidth
            log.debug("[AutoFit] corrective widen column=\(columnID.title) old=\(Int(oldWidth)) new=\(Int(newWidth)) target=\(Int(correctiveWidth))")
        }
    }

    private static func correctiveContentWidth(for column: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(column, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else { return emptyColumnWidth }

        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let percentileWidth = clippingSafePercentileWidth(measuredWidths)
        let contentWidth = percentileFittedContentWidth(for: column, percentileWidth: percentileWidth)
        return ceil(contentWidth.clamped(to: emptyColumnWidth...ColumnWidthPolicy.effectiveMaxWidth(for: column)))
    }

    private static func measuredClippingRatio(for column: ColumnID, files: [CustomFile], fittedWidth: CGFloat) -> CGFloat {
        let (texts, font) = textSamples(column, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else { return .zero }

        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let clippedCount = measuredWidths.filter { measuredWidth in
            requiredContentWidth(for: column, measuredWidth: measuredWidth) > fittedWidth + edgeAlignmentEpsilon
        }.count

        return CGFloat(clippedCount) / CGFloat(measuredWidths.count)
    }

    private static func clippingSafePercentileWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        guard !measuredWidths.isEmpty else { return emptyColumnWidth }

        let sortedWidths = measuredWidths.sorted()
        let percentileIndex = Int(floor(CGFloat(sortedWidths.count - 1) * (1 - correctiveClippingThreshold)))
        return sortedWidths[max(0, min(percentileIndex, sortedWidths.count - 1))]
    }

    private static func percentileFittedContentWidth(for column: ColumnID, percentileWidth: CGFloat) -> CGFloat {
        switch column {
        case .owner:
            return ceil(percentileWidth + 2 * measuredContentInset + ownerColumnInsetBoost)
        default:
            return ceil(percentileWidth + 2 * measuredContentInset + ColumnWidthPolicy.extraReserveWidth(for: column))
        }
    }

    private static func requiredContentWidth(for column: ColumnID, measuredWidth: CGFloat) -> CGFloat {
        switch column {
        case .owner:
            return ceil(measuredWidth + 2 * measuredContentInset + ownerColumnInsetBoost)
        default:
            return ceil(measuredWidth + 2 * measuredContentInset + ColumnWidthPolicy.extraReserveWidth(for: column))
        }
    }

    private static func proposedNameWidth(containerWidth: CGFloat, fittedColumns: [FittedColumn], dividerTotal: CGFloat) -> CGFloat {
        containerWidth - totalFixedWidth(fittedColumns) - dividerTotal - trailingPanelInset
    }

    private static func reclaimWidthFromRightColumns(fittedColumns: inout [FittedColumn], requiredWidth: CGFloat) {
        guard requiredWidth > 0 else { return }

        var reclaimedWidth: CGFloat = 0
        for index in stride(from: fittedColumns.count - 1, through: 0, by: -1) {
            guard reclaimedWidth < requiredWidth else { break }

            let currentWidth = fittedColumns[index].width
            let shrinkableWidth = currentWidth - emptyColumnWidth
            guard shrinkableWidth > 0 else { continue }

            let shrinkAmount = min(shrinkableWidth, requiredWidth - reclaimedWidth)
            fittedColumns[index].width = currentWidth - shrinkAmount
            reclaimedWidth += shrinkAmount
        }
    }

    private static func alignTrailingEdge(fittedColumns: inout [FittedColumn], containerWidth: CGFloat, nameWidth: CGFloat, dividerTotal: CGFloat) {
        guard let lastIndex = fittedColumns.indices.last else { return }

        let remainder = containerWidth - nameWidth - totalFixedWidth(fittedColumns) - dividerTotal - trailingPanelInset
        guard abs(remainder) > edgeAlignmentEpsilon else { return }

        let adjustedWidth = fittedColumns[lastIndex].width + remainder
        fittedColumns[lastIndex].width = max(emptyColumnWidth, adjustedWidth)
    }

    private static func needsUpdate(layout: ColumnLayoutModel, fittedColumns: [FittedColumn], nameWidth: CGFloat) -> Bool {
        let isNameStable = abs(layout.nameWidth - nameWidth) < widthStabilityEpsilon
        let areFixedColumnsStable = fittedColumns.allSatisfy { fittedColumn in
            guard let index = layout.columns.firstIndex(where: { $0.id == fittedColumn.id }) else { return true }
            return abs(layout.columns[index].width - fittedColumn.width) < widthStabilityEpsilon
        }
        return !isNameStable || !areFixedColumnsStable
    }

    private static func apply(fittedColumns: [FittedColumn], nameWidth: CGFloat, to layout: ColumnLayoutModel) {
        for fittedColumn in fittedColumns.reversed() {
            layout.setWidth(fittedColumn.width, for: fittedColumn.id)
        }
        layout.nameWidth = nameWidth
    }

    private static func totalFixedWidth(_ fittedColumns: [FittedColumn]) -> CGFloat {
        fittedColumns.reduce(CGFloat.zero) { partialWidth, fittedColumn in
            partialWidth + fittedColumn.width
        }
    }

    private static func totalDividerWidth(for fixedColumnCount: Int) -> CGFloat {
        CGFloat(fixedColumnCount) * dividerWidth
    }


    private static func pt(_ value: CGFloat) -> String {
        String(format: "%.1fpt", value)
    }

    private static func isRealContent(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let stripped = text.trimmingCharacters(in: .whitespaces)
        return !stripped.allSatisfy { character in
            character == "-" || character == "\u{2013}" || character == "\u{2014}" || character == "\u{2015}"
        }
    }


    private static func textSamples(_ col: ColumnID, files: [CustomFile]) -> ([String], NSFont) {
        switch col {
        case .size:           (files.map(\.displaySizeFormatted),   .systemFont(ofSize: 12))
        case .dateModified:   (files.map(\.modifiedDateFormatted),  .systemFont(ofSize: 12))
        case .kind:           (files.map(\.kindFormatted),          .systemFont(ofSize: 12))
        case .permissions:    (files.map(\.permissionsFormatted),   .monospacedSystemFont(ofSize: 11, weight: .regular))
        case .owner:          (files.map(\.ownerFormatted),         .systemFont(ofSize: 12, weight: .regular))
        case .childCount:     (files.map(\.childCountFormatted),    .systemFont(ofSize: 12))
        case .dateCreated:    (files.map(\.creationDateFormatted),  .systemFont(ofSize: 12))
        case .dateLastOpened: (files.map(\.lastOpenedFormatted),    .systemFont(ofSize: 12))
        case .dateAdded:      (files.map(\.dateAddedFormatted),     .systemFont(ofSize: 12))
        case .group:          (files.map(\.groupNameFormatted),     .systemFont(ofSize: 12))
        case .name:           ([], .systemFont(ofSize: 12))
        }
    }
}


private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
