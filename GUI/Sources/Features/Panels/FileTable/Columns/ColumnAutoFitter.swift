// ColumnAutoFitter.swift
// MiMiNavigator
//
// Created by Claude on 24.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Content-aware auto-fit for fixed columns.
//   Right→left: each column shrinks to its max content width.
//   All recovered space donated to Name (leftmost).
//   Header labels are NOT considered — only cell content matters.

import AppKit
import FileModelKit
import SwiftUI


// MARK: - ColumnAutoFitter

enum ColumnAutoFitter {

    private static let dividerWidth: CGFloat = 14
    private static let minNameWidth: CGFloat = 120
    private static let edgeMargin: CGFloat = 5
    /// Floor for fully empty (placeholder-only) columns
    private static let emptyColWidth: CGFloat = 24


    // MARK: - Public

    /// Recompute all visible fixed column widths based on cell content only.
    /// Algorithm: right→left, each column shrinks to max content width,
    /// freed space goes to Name.
    static func autoFitAll(layout: ColumnLayoutModel, files: [CustomFile]) {
        guard layout.containerWidth > 0 else { return }
        guard !files.isEmpty else { return }

        let visibleFixed = layout.fixedColumns
        guard !visibleFixed.isEmpty else { return }

        // Phase 1: measure content width for each fixed col, right→left
        var colWidths: [(ColumnID, CGFloat)] = []
        for spec in visibleFixed.reversed() {
            let w = contentWidth(for: spec.id, files: files)
            colWidths.append((spec.id, w))
        }
        colWidths.reverse()

        // Phase 2: compute Name width = container minus all fixed cols minus dividers
        let totalFixed = colWidths.reduce(CGFloat(0)) { $0 + $1.1 }
        let divTotal = CGFloat(visibleFixed.count) * dividerWidth
        var nameW = layout.containerWidth - totalFixed - divTotal - edgeMargin


        // Phase 3: if Name still squeezed, shrink rightmost cols further
        if nameW < minNameWidth {
            let deficit = minNameWidth - nameW
            var recovered: CGFloat = 0
            for i in stride(from: colWidths.count - 1, through: 0, by: -1) {
                guard recovered < deficit else { break }
                let (_, w) = colWidths[i]
                let floor = emptyColWidth
                let canShrink = w - floor
                if canShrink > 0 {
                    let shrink = min(canShrink, deficit - recovered)
                    colWidths[i] = (colWidths[i].0, w - shrink)
                    recovered += shrink
                }
            }
            let newTotalFixed = colWidths.reduce(CGFloat(0)) { $0 + $1.1 }
            nameW = layout.containerWidth - newTotalFixed - divTotal - edgeMargin
        }
        nameW = max(minNameWidth, nameW)


        // Phase 4: stability guard — skip if nothing changed
        let nameStable = abs(layout.nameWidth - nameW) < 1.0
        let colsStable = colWidths.allSatisfy { id, w in
            guard let idx = layout.columns.firstIndex(where: { $0.id == id }) else { return true }
            return abs(layout.columns[idx].width - w) < 1.0
        }
        guard !nameStable || !colsStable else { return }

        // Phase 5: apply — fixed cols first, then Name gets the rest
        for (id, w) in colWidths {
            layout.setWidth(w, for: id)
        }
        layout.nameWidth = nameW

        let detail = colWidths.map { "\($0.0.title)=\(Int($0.1))" }.joined(separator: " ")
        log.info("[AutoFit] Name=\(Int(nameW))pt  \(detail)")
    }


    // MARK: - Content measurement

    /// Measure column width needed for actual cell content only.
    /// Header label is NOT considered.
    /// Empty/placeholder columns → `emptyColWidth`.
    /// Content columns → max text width so nothing is clipped.
    private static func contentWidth(for col: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(col, files: files)
        let meaningful = texts.filter { isRealContent($0) }
        guard !meaningful.isEmpty else {
            return emptyColWidth
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let maxW = meaningful.reduce(CGFloat(0)) {
            max($0, ($1 as NSString).size(withAttributes: attrs).width)
        }
        let padded = ceil(maxW + 2 * TableColumnDefaults.cellPadding + 5)
        // clamp to content-sensible range — ignore header, use col min/max
        return padded.clamped(to: emptyColWidth...col.maxWidth)
    }


    // MARK: - Helpers

    /// True when the cell text carries actual data (not a placeholder dash/empty).
    private static func isRealContent(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let stripped = text.trimmingCharacters(in: .whitespaces)
        return !stripped.allSatisfy { $0 == "-" || $0 == "\u{2013}" || $0 == "\u{2014}" || $0 == "\u{2015}" }
    }


    /// Extract display strings and font for a column.
    private static func textSamples(_ col: ColumnID, files: [CustomFile]) -> ([String], NSFont) {
        switch col {
        case .size:           (files.map(\.fileSizeFormatted),      .systemFont(ofSize: 12))
        case .dateModified:   (files.map(\.modifiedDateFormatted),  .systemFont(ofSize: 12))
        case .kind:           (files.map(\.kindFormatted),          .systemFont(ofSize: 12))
        case .permissions:    (files.map(\.permissionsFormatted),   .monospacedSystemFont(ofSize: 11, weight: .regular))
        case .owner:          (files.map(\.ownerFormatted),         .systemFont(ofSize: 12))
        case .childCount:     (files.map(\.childCountFormatted),    .systemFont(ofSize: 12))
        case .dateCreated:    (files.map(\.creationDateFormatted),  .systemFont(ofSize: 12))
        case .dateLastOpened: (files.map(\.lastOpenedFormatted),    .systemFont(ofSize: 12))
        case .dateAdded:      (files.map(\.dateAddedFormatted),     .systemFont(ofSize: 12))
        case .group:          (files.map(\.groupNameFormatted),     .systemFont(ofSize: 12))
        case .name:           ([], .systemFont(ofSize: 12))
        }
    }
}


// MARK: - CGFloat clamp

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
