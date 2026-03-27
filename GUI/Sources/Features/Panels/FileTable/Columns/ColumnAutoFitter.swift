// ColumnAutoFitter.swift
// MiMiNavigator
//
// Created by Claude on 24.03.2026.
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FileModelKit
import SwiftUI


enum ColumnAutoFitter {

    private static let dividerWidth: CGFloat = 14
    private static let minNameWidth: CGFloat = 120
    private static let emptyColumnWidth: CGFloat = 24
    private static let measuredContentInset: CGFloat = 5
    private static let trailingPanelInset: CGFloat = 17
    private static let ownerColumnInsetBoost: CGFloat = 8
    private static let widthStabilityEpsilon: CGFloat = 1
    private static let edgeAlignmentEpsilon: CGFloat = 0.5


    static func autoFitAll(layout: ColumnLayoutModel, files: [CustomFile]) {
        guard shouldAutoFit(layout: layout, files: files) else { return }

        let visibleFixedColumns = layout.fixedColumns
        var fitWidths = measuredFixedWidths(for: visibleFixedColumns, files: files)
        let dividerTotal = totalDividerWidth(for: visibleFixedColumns.count)
        var nameWidth = proposedNameWidth(containerWidth: layout.containerWidth, fitWidths: fitWidths, dividerTotal: dividerTotal)

        if nameWidth < minNameWidth {
            reclaimWidthFromRightColumns(fitWidths: &fitWidths, requiredWidth: minNameWidth - nameWidth)
            nameWidth = proposedNameWidth(containerWidth: layout.containerWidth, fitWidths: fitWidths, dividerTotal: dividerTotal)
        }

        nameWidth = max(minNameWidth, nameWidth)
        alignTrailingEdge(fitWidths: &fitWidths, containerWidth: layout.containerWidth, nameWidth: nameWidth, dividerTotal: dividerTotal)

        guard needsUpdate(layout: layout, fitWidths: fitWidths, nameWidth: nameWidth) else { return }

        apply(fitWidths: fitWidths, nameWidth: nameWidth, to: layout)
        logAutoFit(layout: layout, fitWidths: fitWidths, nameWidth: nameWidth)
    }

    private static func shouldAutoFit(layout: ColumnLayoutModel, files: [CustomFile]) -> Bool {
        layout.containerWidth > 0 && !files.isEmpty && !layout.fixedColumns.isEmpty
    }

    private static func logAutoFit(layout: ColumnLayoutModel, fitWidths: [(ColumnID, CGFloat)], nameWidth: CGFloat) {
        let detail = fitWidths.map { "\($0.0.title)=\(Int($0.1))" }.joined(separator: " ")
        log.debug("[AutoFit] panelWidth=\(Int(layout.containerWidth)) name=\(Int(nameWidth)) trailingInset=\(Int(trailingPanelInset)) \(detail)")
    }


    private static func contentWidth(for col: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(col, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else { return emptyColumnWidth }

        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let fittedWidth: CGFloat

        switch col {
        case .owner:
            fittedWidth = ownerContentWidth(measuredWidths)
        default:
            fittedWidth = weightedAverageContentWidth(measuredWidths)
        }

        return fittedWidth.clamped(to: emptyColumnWidth...col.maxWidth)
    }

    private static func measuredTextWidths(_ texts: [String], font: NSFont) -> [CGFloat] {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return texts.map { ($0 as NSString).size(withAttributes: attributes).width }
    }

    private static func weightedAverageContentWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        let averageWidth = measuredWidths.reduce(0, +) / CGFloat(measuredWidths.count)
        return ceil(averageWidth + 2 * measuredContentInset)
    }

    private static func ownerContentWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        guard let maximumWidth = measuredWidths.max() else { return emptyColumnWidth }
        return ceil(maximumWidth + 2 * measuredContentInset + ownerColumnInsetBoost)
    }

    private static func measuredFixedWidths(
        for columns: [ColumnSpec],
        files: [CustomFile]
    ) -> [(ColumnID, CGFloat)] {
        var fitWidths: [(ColumnID, CGFloat)] = []

        for spec in columns.reversed() {
            fitWidths.append((spec.id, contentWidth(for: spec.id, files: files)))
        }

        return fitWidths.reversed()
    }

    private static func proposedNameWidth(
        containerWidth: CGFloat,
        fitWidths: [(ColumnID, CGFloat)],
        dividerTotal: CGFloat
    ) -> CGFloat {
        containerWidth - totalFixedWidth(fitWidths) - dividerTotal - trailingPanelInset
    }

    private static func reclaimWidthFromRightColumns(fitWidths: inout [(ColumnID, CGFloat)], requiredWidth: CGFloat) {
        guard requiredWidth > 0 else { return }

        var reclaimedWidth: CGFloat = 0
        for index in stride(from: fitWidths.count - 1, through: 0, by: -1) {
            guard reclaimedWidth < requiredWidth else { break }

            let currentWidth = fitWidths[index].1
            let shrinkableWidth = currentWidth - emptyColumnWidth
            guard shrinkableWidth > 0 else { continue }

            let shrinkAmount = min(shrinkableWidth, requiredWidth - reclaimedWidth)
            fitWidths[index].1 = currentWidth - shrinkAmount
            reclaimedWidth += shrinkAmount
        }
    }

    private static func alignTrailingEdge(fitWidths: inout [(ColumnID, CGFloat)], containerWidth: CGFloat, nameWidth: CGFloat, dividerTotal: CGFloat) {
        guard let lastIndex = fitWidths.indices.last else { return }

        let remainder = containerWidth - nameWidth - totalFixedWidth(fitWidths) - dividerTotal - trailingPanelInset
        guard abs(remainder) > edgeAlignmentEpsilon else { return }

        let adjustedWidth = fitWidths[lastIndex].1 + remainder
        fitWidths[lastIndex].1 = max(emptyColumnWidth, adjustedWidth)
    }

    private static func needsUpdate(layout: ColumnLayoutModel, fitWidths: [(ColumnID, CGFloat)], nameWidth: CGFloat) -> Bool {
        let isNameStable = abs(layout.nameWidth - nameWidth) < widthStabilityEpsilon
        let areFixedColumnsStable = fitWidths.allSatisfy { id, width in
            guard let index = layout.columns.firstIndex(where: { $0.id == id }) else { return true }
            return abs(layout.columns[index].width - width) < widthStabilityEpsilon
        }

        return !isNameStable || !areFixedColumnsStable
    }

    private static func apply(
        fitWidths: [(ColumnID, CGFloat)],
        nameWidth: CGFloat,
        to layout: ColumnLayoutModel
    ) {
        for (id, width) in fitWidths.reversed() {
            layout.setWidth(width, for: id)
        }
        layout.nameWidth = nameWidth
    }

    private static func totalFixedWidth(_ fitWidths: [(ColumnID, CGFloat)]) -> CGFloat {
        fitWidths.reduce(CGFloat.zero) { partialWidth, item in
            partialWidth + item.1
        }
    }

    private static func totalDividerWidth(for fixedColumnCount: Int) -> CGFloat {
        CGFloat(fixedColumnCount) * dividerWidth
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
        case .size:           (files.map(\.fileSizeFormatted),      .systemFont(ofSize: 12))
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
