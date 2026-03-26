// ColumnAutoFitter.swift
// MiMiNavigator
//
// Created by Claude on 24.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Content-aware auto-fit for fixed columns on directory change.
//   Right→left: each column sized to weighted-average content width + 2 chars margin.
//   Outlier-long values are NOT considered — SwiftUI truncates them naturally.
//   Header labels are NOT considered — only cell content matters.
//   Then Name gets exactly what's left so rightmost column touches right edge.

import AppKit
import FileModelKit
import SwiftUI


// MARK: - ColumnAutoFitter

enum ColumnAutoFitter {

    private static let dividerWidth: CGFloat = 14
    private static let minNameWidth: CGFloat = 120
    /// Floor for fully empty (placeholder-only) columns
    private static let emptyColWidth: CGFloat = 24


    // MARK: - Public

    /// Recompute all visible fixed column widths based on cell content only.
    ///
    /// Algorithm:
    ///  1. Walk fixed columns **right → left** (rightmost first).
    ///  2. For each column, measure max content text width among all files.
    ///  3. Set that column's width = measured content width (clamped to sane range).
    ///  4. After all fixed columns are sized, compute Name width =
    ///     containerWidth − sum(fixedWidths) − dividers.
    ///     This ensures the rightmost fixed column sits flush against the right edge.
    ///  5. If Name would be too narrow, shrink rightmost columns further.
    static func autoFitAll(layout: ColumnLayoutModel, files: [CustomFile]) {
        guard layout.containerWidth > 0, !files.isEmpty else { return }
        let visibleFixed = layout.fixedColumns
        guard !visibleFixed.isEmpty else { return }

        // Step 1-3: measure each fixed column right→left, set width immediately
        var fitWidths: [(ColumnID, CGFloat)] = []
        for spec in visibleFixed.reversed() {
            let w = contentWidth(for: spec.id, files: files)
            fitWidths.append((spec.id, w))
        }
        fitWidths.reverse()


        // Step 4: Name = container − fixed − dividers
        // dividers: N total (1 nameDivider + N-1 between fixed cols = N)
        let totalFixed = fitWidths.reduce(CGFloat(0)) { $0 + $1.1 }
        let divTotal = CGFloat(visibleFixed.count) * dividerWidth
        var nameW = layout.containerWidth - totalFixed - divTotal

        // Step 5: if Name squeezed, shrink rightmost cols to free space
        if nameW < minNameWidth {
            let deficit = minNameWidth - nameW
            var recovered: CGFloat = 0
            for i in stride(from: fitWidths.count - 1, through: 0, by: -1) {
                guard recovered < deficit else { break }
                let w = fitWidths[i].1
                let canShrink = w - emptyColWidth
                if canShrink > 0 {
                    let shrink = min(canShrink, deficit - recovered)
                    fitWidths[i] = (fitWidths[i].0, w - shrink)
                    recovered += shrink
                }
            }
            let newTotal = fitWidths.reduce(CGFloat(0)) { $0 + $1.1 }
            nameW = layout.containerWidth - newTotal - divTotal
        }
        nameW = max(minNameWidth, nameW)


        // Step 6: push any remaining slack into last fixed column
        // so rightmost column sits flush against the right panel edge.
        // Slack comes from subpixel ceil() rounding across N columns.
        let finalFixed = fitWidths.reduce(CGFloat(0)) { $0 + $1.1 }
        let slack = layout.containerWidth - nameW - finalFixed - divTotal
        if slack > 1, let lastIdx = fitWidths.indices.last {
            fitWidths[lastIdx].1 += slack
        }


        // Stability guard — skip when nothing changed
        let nameStable = abs(layout.nameWidth - nameW) < 1.0
        let colsStable = fitWidths.allSatisfy { id, w in
            guard let idx = layout.columns.firstIndex(where: { $0.id == id }) else { return true }
            return abs(layout.columns[idx].width - w) < 1.0
        }
        guard !nameStable || !colsStable else { return }

        // Apply: fixed columns right→left, then Name
        for (id, w) in fitWidths.reversed() {
            layout.setWidth(w, for: id)
        }
        layout.nameWidth = nameW

        let detail = fitWidths.map { "\($0.0.title)=\(Int($0.1))" }.joined(separator: " ")
        log.info("[AutoFit] Name=\(Int(nameW))  \(detail)")
    }


    // MARK: - Content measurement

    /// Extra character slots added on top of the weighted-average width.
    private static let marginChars: Int = 2

    /// Measure column width using weighted-average text width + margin.
    /// Long outliers are ignored — SwiftUI will truncate them naturally.
    /// Header label is NOT considered.
    private static func contentWidth(for col: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(col, files: files)
        let meaningful = texts.filter { isRealContent($0) }
        guard !meaningful.isEmpty else { return emptyColWidth }
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        // measure each cell
        let widths = meaningful.map { ($0 as NSString).size(withAttributes: attrs).width }
        // weighted average (sum / count)
        let avgW = widths.reduce(0, +) / CGFloat(widths.count)
        // margin = width of 2 extra "0" glyphs at column font
        let marginW = ("00" as NSString).size(withAttributes: attrs).width
        let padded = ceil(avgW + marginW + 2 * TableColumnDefaults.cellPadding)
        return padded.clamped(to: emptyColWidth...col.maxWidth)
    }


    // MARK: - Helpers

    private static func isRealContent(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let stripped = text.trimmingCharacters(in: .whitespaces)
        return !stripped.allSatisfy { $0 == "-" || $0 == "\u{2013}" || $0 == "\u{2014}" || $0 == "\u{2015}" }
    }


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
