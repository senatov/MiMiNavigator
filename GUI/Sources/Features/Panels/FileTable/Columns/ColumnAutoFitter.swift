// ColumnAutoFitter.swift
// MiMiNavigator
//
// Created by Claude on 24.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Content-aware auto-fit for fixed columns on directory change.
//   Shrinks data columns to match actual content width,
//   collapses empty/dash columns to minimum, donates saved space to Name.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - ColumnAutoFitter

enum ColumnAutoFitter {

    private static let dividerWidth: CGFloat = 14
    private static let minNameWidth: CGFloat = 60
    private static let edgeMargin: CGFloat = 5

    /// Recompute all visible fixed column widths from file content,
    /// then donate recovered space to the Name column.
    static func autoFitAll(layout: ColumnLayoutModel, files: [CustomFile]) {
        guard layout.containerWidth > 0 else {
            log.debug("[AutoFit] skip — container not measured yet")
            return
        }
        guard !files.isEmpty else {
            log.debug("[AutoFit] skip — empty file list")
            return
        }

        let visibleFixed = layout.fixedColumns
        guard !visibleFixed.isEmpty else { return }

        // compute optimal widths first, then check if anything actually changed
        var optimalWidths: [(ColumnID, CGFloat)] = []
        var totalFixed: CGFloat = 0

        for spec in visibleFixed {
            let optimal = optimalWidth(for: spec.id, files: files)
            optimalWidths.append((spec.id, optimal))
            totalFixed += optimal
        }

        let divCount = CGFloat(visibleFixed.count)
        let available = layout.containerWidth - totalFixed - divCount * dividerWidth - edgeMargin
        let newNameW = max(minNameWidth, available)

        // skip mutation when layout is already stable (prevents feedback loops)
        let nameStable = abs(layout.nameWidth - newNameW) < 1.0
        let colsStable = optimalWidths.allSatisfy { id, w in
            guard let idx = layout.columns.firstIndex(where: { $0.id == id }) else { return true }
            return abs(layout.columns[idx].width - w) < 1.0
        }
        guard !nameStable || !colsStable else { return }

        for (id, w) in optimalWidths {
            layout.setWidth(w, for: id)
        }
        layout.nameWidth = newNameW

        log.info("[AutoFit] fitted \(visibleFixed.count) cols, Name=\(Int(newNameW))pt, fixed=\(Int(totalFixed))pt")
    }

    // MARK: - Private

    /// Compute optimal column width based on actual cell content.
    ///
    /// Policy:
    /// - **All values empty/placeholder** → collapse to `minDragWidth` (save max space)
    /// - **Has real data** → use average text width (not max!) so common values fit
    ///   comfortably while outliers just truncate. Clamp to `[minWidth … maxWidth]`.
    private static func optimalWidth(for col: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(col, files: files)

        let meaningful = texts.filter { !$0.isEmpty && $0 != "-" && $0 != "–" }
        guard !meaningful.isEmpty else {
            return col.minDragWidth
        }

        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let widths = meaningful.map { ($0 as NSString).size(withAttributes: attrs).width }

        // use max of avg content width and header label width — header must never be clipped
        let avgW = widths.reduce(0, +) / CGFloat(widths.count)
        let contentW = ceil(avgW + 2 * TableColumnDefaults.cellPadding + 5)
        let headerW = col.minHeaderWidth
        let optimal = max(contentW, headerW)
        return optimal.clamped(to: col.minWidth...col.maxWidth)
    }

    /// Extract display strings and font for a column — mirrors TableHeaderView.textsAndFont
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
