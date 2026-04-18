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
        log.verbose("[AutoFit] autoFitAll start — container=\(pt(layout.containerWidth)) files=\(files.count) fixedCols=\(layout.fixedColumns.count)")
        guard let result = makeAutoFitResult(layout: layout, files: files) else {
            log.verbose("[AutoFit] autoFitAll skip — no result (empty files or zero width)")
            return
        }
        guard needsUpdate(layout: layout, fittedColumns: result.fittedColumns, nameWidth: result.nameWidth) else {
            log.verbose("[AutoFit] autoFitAll skip — widths stable")
            return
        }
        let colSummary = result.fittedColumns.map { "\($0.id.rawValue)=\(pt($0.width))" }.joined(separator: " ")
        log.info("[AutoFit] APPLY name=\(pt(result.nameWidth)) \(colSummary)")
        apply(fittedColumns: result.fittedColumns, nameWidth: result.nameWidth, to: layout)
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

        var nameWidth = finalizedNameWidth(
            containerWidth: layout.containerWidth, fittedColumns: &fittedColumns, dividerTotal: dividerTotal)

        for _ in 2...3 {
            let requiresCorrection = needsCorrectivePass(
                columns: visibleFixedColumns,
                fittedColumns: fittedColumns,
                files: files,
                containerWidth: layout.containerWidth,
                nameWidth: nameWidth,
                dividerTotal: dividerTotal
            )
            guard requiresCorrection else {

                break
            }
            applyCorrectivePass(columns: visibleFixedColumns, fittedColumns: &fittedColumns, files: files)
            nameWidth = finalizedNameWidth(
                containerWidth: layout.containerWidth, fittedColumns: &fittedColumns, dividerTotal: dividerTotal)

        }

        return AutoFitResult(fittedColumns: fittedColumns, nameWidth: nameWidth)
    }

    private static func shouldAutoFit(layout: ColumnLayoutModel, files: [CustomFile]) -> Bool {
        layout.containerWidth > 0 && !files.isEmpty && !layout.fixedColumns.isEmpty
    }

    private static func contentWidth(for col: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(col, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else {
            if col == .size {
                let fallback = ColumnWidthPolicy.sizeColumnFallbackWidth()
                log.verbose("[AutoFit] contentWidth \(col.rawValue) fallback=\(pt(fallback))")
                return fallback
            }
            log.verbose("[AutoFit] contentWidth \(col.rawValue) empty")
            return emptyColumnWidth
        }
        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let fittedWidth = fittedContentWidth(for: col, measuredWidths: measuredWidths)
        let maxW = ColumnWidthPolicy.effectiveMaxWidth(for: col)
        var clampedWidth = fittedWidth.clamped(to: emptyColumnWidth...maxW)
        // Size col: if not all dirs resolved yet, don't shrink below fallback
        if col == .size && meaningfulTexts.count < texts.count {
            let fallback = ColumnWidthPolicy.sizeColumnFallbackWidth()
            if clampedWidth < fallback {
                log.verbose("[AutoFit] contentWidth size partial floor to fallback")
                clampedWidth = fallback
            }
        }
        log.verbose("[AutoFit] contentWidth \(col.rawValue) \(pt(clampedWidth))")
        return clampedWidth
    }

    private static func fittedContentWidth(for column: ColumnID, measuredWidths: [CGFloat]) -> CGFloat {
        switch column {
            case .owner:
                ownerContentWidth(measuredWidths)
            case .size:
                // size col: use weighted-average so wide values (big files) pull
                // the column wider — prevents "523,3 MB" clipping when most are "53 KB"
                sizeColumnContentWidth(measuredWidths)
            default:
                weightedAverageContentWidth(measuredWidths, for: column)
        }
    }

    private static func measuredTextWidths(_ texts: [String], font: NSFont) -> [CGFloat] {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return texts.map { ($0 as NSString).size(withAttributes: attributes).width }
    }

    /// Trimmed weighted average: discard 10% smallest and 10% largest widths,
    /// then compute weighted average on the remaining 80% (weight = width itself).
    /// Formula on trimmed set: Σ(w_i²) / Σ(w_i)
    private static func weightedAverageContentWidth(_ measuredWidths: [CGFloat], for column: ColumnID) -> CGFloat {
        guard !measuredWidths.isEmpty else { return emptyColumnWidth }
        let trimmed = trimmedWidths(measuredWidths, trimFraction: 0.10)
        guard !trimmed.isEmpty else { return emptyColumnWidth }
        let sumW = trimmed.reduce(0, +)
        guard sumW > 0 else { return emptyColumnWidth }
        let sumWW = trimmed.reduce(0) { $0 + $1 * $1 }
        let weighted = sumWW / sumW
        let extraWidth = ColumnWidthPolicy.extraReserveWidth(for: column)
        return ceil(weighted + 2 * measuredContentInset + extraWidth)
    }

    /// Size column: trim 10% extremes, then use P85 of the remaining set
    /// so the widest formatted values ("523,3 MB") aren't clipped by shorter ones ("53 KB").
    private static func sizeColumnContentWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        guard !measuredWidths.isEmpty else { return emptyColumnWidth }
        let trimmed = trimmedWidths(measuredWidths, trimFraction: 0.10)
        guard !trimmed.isEmpty else { return emptyColumnWidth }
        let sorted = trimmed.sorted()
        let p85Index = min(Int(ceil(Double(sorted.count) * 0.85)) - 1, sorted.count - 1)
        let percentileWidth = sorted[max(0, p85Index)]
        let extraWidth = ColumnWidthPolicy.extraReserveWidth(for: .size)
        return ceil(percentileWidth + 2 * measuredContentInset + extraWidth)
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

    private static func finalizedNameWidth(containerWidth: CGFloat, fittedColumns: inout [FittedColumn], dividerTotal: CGFloat)
        -> CGFloat
    {
        var nameWidth = proposedNameWidth(containerWidth: containerWidth, fittedColumns: fittedColumns, dividerTotal: dividerTotal)
        if nameWidth < minNameWidth {
            reclaimWidthFromRightColumns(fittedColumns: &fittedColumns, requiredWidth: minNameWidth - nameWidth)
            nameWidth = proposedNameWidth(containerWidth: containerWidth, fittedColumns: fittedColumns, dividerTotal: dividerTotal)
        }
        nameWidth = max(minNameWidth, min(maxNameWidth(for: containerWidth), nameWidth))
        nameWidth = alignTrailingEdge(
            fittedColumns: &fittedColumns, containerWidth: containerWidth, nameWidth: nameWidth, dividerTotal: dividerTotal)
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
        for column in columns {
            guard let fittedColumn = fittedColumns.first(where: { $0.id == column.id }) else { continue }
            let clippingRatio = measuredClippingRatio(for: column.id, files: files, fittedWidth: fittedColumn.width)
            if clippingRatio > correctiveClippingThreshold {
                return true
            }
        }

        return false
    }

    private static func applyCorrectivePass(columns: [ColumnSpec], fittedColumns: inout [FittedColumn], files: [CustomFile]) {
        for index in fittedColumns.indices {
            let columnID = fittedColumns[index].id
            guard columns.contains(where: { $0.id == columnID }) else { continue }
            let correctiveWidth = correctiveContentWidth(for: columnID, files: files)
            let newWidth = min(correctiveWidth, columnID.maxWidth)
            fittedColumns[index].width = newWidth
        }
    }

    private static func correctiveContentWidth(for column: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(column, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else {
            // size col: don't collapse to 24pt when dirs haven't resolved yet
            if column == .size {
                return ColumnWidthPolicy.sizeColumnFallbackWidth()
            }
            return emptyColumnWidth
        }
        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let percentileWidth = clippingSafePercentileWidth(measuredWidths)
        var result = percentileFittedContentWidth(for: column, percentileWidth: percentileWidth)
        // Size col: don't shrink below fallback when dirs still resolving
        if column == .size && meaningfulTexts.count < texts.count {
            let fallback = ColumnWidthPolicy.sizeColumnFallbackWidth()
            result = max(result, fallback)
        }
        return ceil(result.clamped(to: emptyColumnWidth...ColumnWidthPolicy.effectiveMaxWidth(for: column)))
    }

    private static func measuredClippingRatio(for column: ColumnID, files: [CustomFile], fittedWidth: CGFloat) -> CGFloat {
        let (texts, font) = textSamples(column, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else { return .zero }

        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let clippedCount =
            measuredWidths.filter { measuredWidth in
                requiredContentWidth(for: column, measuredWidth: measuredWidth) > fittedWidth + edgeAlignmentEpsilon
            }
            .count

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

    /// Give any sub-pixel remainder to Name column (leftmost), not to the last fixed column.
    /// This ensures Name always gets the surplus width after fixed columns are sized.
    private static func alignTrailingEdge(
        fittedColumns: inout [FittedColumn], containerWidth: CGFloat, nameWidth: CGFloat, dividerTotal: CGFloat
    ) -> CGFloat {
        let remainder = containerWidth - nameWidth - totalFixedWidth(fittedColumns) - dividerTotal - trailingPanelInset
        guard abs(remainder) > edgeAlignmentEpsilon else { return nameWidth }
        let adjusted = max(minNameWidth, nameWidth + remainder)
        log.verbose("[AutoFit] alignTrailing remainder=\(pt(remainder)) → Name")
        return adjusted
    }

    private static func needsUpdate(layout: ColumnLayoutModel, fittedColumns: [FittedColumn], nameWidth: CGFloat) -> Bool {
        let nameDelta = abs(layout.nameWidth - nameWidth)
        let isNameStable = nameDelta < widthStabilityEpsilon
        var unstableCols: [String] = []
        let areFixedColumnsStable = fittedColumns.allSatisfy { fittedColumn in
            guard let index = layout.columns.firstIndex(where: { $0.id == fittedColumn.id }) else { return true }
            let colDelta = abs(layout.columns[index].width - fittedColumn.width)
            if colDelta >= widthStabilityEpsilon {
                unstableCols.append("\(fittedColumn.id.rawValue)Δ\(pt(colDelta))")
            }
            return colDelta < widthStabilityEpsilon
        }
        if !isNameStable || !areFixedColumnsStable {
            let unstableSummary = unstableCols.isEmpty ? "none" : unstableCols.joined(separator: " ")
            log.verbose("[AutoFit] needsUpdate=true nameΔ\(pt(nameDelta)) fixed=\(unstableSummary)")
        }
        return !isNameStable || !areFixedColumnsStable
    }

    private static func apply(fittedColumns: [FittedColumn], nameWidth: CGFloat, to layout: ColumnLayoutModel) {
        for fittedColumn in fittedColumns.reversed() {
            layout.setWidth(fittedColumn.width, for: fittedColumn.id)
        }
        layout.nameWidth = nameWidth
        layout.autoFitGeneration += 1
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
            case .size: (files.map(\.displaySizeFormatted), .systemFont(ofSize: 12))
            case .dateModified: (files.map(\.modifiedDateFormatted), .systemFont(ofSize: 12))
            case .kind: (files.map(\.kindFormatted), .systemFont(ofSize: 12))
            case .permissions: (files.map(\.permissionsFormatted), .monospacedSystemFont(ofSize: 11, weight: .regular))
            case .owner: (files.map(\.ownerFormatted), .systemFont(ofSize: 12, weight: .regular))
            case .childCount: (files.map(\.childCountFormatted), .systemFont(ofSize: 12))
            case .dateCreated: (files.map(\.creationDateFormatted), .systemFont(ofSize: 12))
            case .dateLastOpened: (files.map(\.lastOpenedFormatted), .systemFont(ofSize: 12))
            case .dateAdded: (files.map(\.dateAddedFormatted), .systemFont(ofSize: 12))
            case .group: (files.map(\.groupNameFormatted), .systemFont(ofSize: 12))
            case .name: ([], .systemFont(ofSize: 12))
        }
    }


    /// Discard `trimFraction` from each end of the sorted widths array.
    /// E.g. trimFraction=0.10 drops 10% smallest + 10% largest = 20% total.
    /// For small arrays (< 5 elements), returns the full array untrimmed.
    private static func trimmedWidths(_ widths: [CGFloat], trimFraction: Double) -> [CGFloat] {
        guard widths.count >= 5 else { return widths }
        let sorted = widths.sorted()
        let trimCount = max(1, Int(floor(Double(sorted.count) * trimFraction)))
        let lo = trimCount
        let hi = sorted.count - trimCount
        guard lo < hi else { return widths }
        return Array(sorted[lo..<hi])
    }
}


extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
