// ColumnWidthPolicy.swift
// MiMiNavigator
//
// Created by Claude on 28.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
//
// Description: Per-column width policy — max-width overrides, extra reserves,
//              single-char reserve widths. Extracted from ColumnAutoFitter
//              to keep sizing rules in one place.

import AppKit
import SwiftUI


// MARK: - ColumnWidthPolicy

enum ColumnWidthPolicy {

    /// Effective upper bound for auto-fit. Some columns need more room
    /// than their default `ColumnID.maxWidth` allows.
    static func effectiveMaxWidth(for column: ColumnID) -> CGFloat {
        let base = column.maxWidth
        return base * maxWidthMultiplier(for: column)
    }



    /// Extra width added on top of measured average content width.
    /// Covers trailing digit / separator that the average may miss.
    static func extraReserveWidth(for column: ColumnID) -> CGFloat {
        switch column {
        case .size, .permissions, .dateModified, .dateCreated, .dateLastOpened:
            return singleCharReserve(for: column)
        default:
            return .zero
        }
    }



    /// Minimum width for Size column when no real content is available.
    /// Based on a typical formatted size string ("999,99 MB").
    /// Prevents Size from collapsing to 24pt when all entries are directories
    /// with deferred size calculation.
    static func sizeColumnFallbackWidth() -> CGFloat {
        let reference = "999,99 MB"
        let font = NSFont.systemFont(ofSize: 12)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textWidth = (reference as NSString).size(withAttributes: attrs).width
        let result = ceil(textWidth + 2 * 5 + singleCharReserve(for: .size))
        log.verbose("[AutoFit] sizeColumnFallbackWidth=\(String(format: "%.1f", result))pt")
        return result
    }



    // MARK: - Private

    /// Per-column multiplier on `ColumnID.maxWidth`.
    /// Only `.size` needs a wider ceiling — formatted sizes like
    /// "1 234 567 890" can exceed the char-based estimate.
    private static func maxWidthMultiplier(for column: ColumnID) -> CGFloat {
        switch column {
        case .size:
            return 2.0
        default:
            return 1.0
        }
    }



    /// Width of a single "8" glyph at the column's font —
    /// used as a padding reserve for numeric columns.
    private static func singleCharReserve(for column: ColumnID) -> CGFloat {
        let font: NSFont = switch column {
        case .permissions:
            .monospacedSystemFont(ofSize: 11, weight: .regular)
        default:
            .systemFont(ofSize: 12)
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil(("8" as NSString).size(withAttributes: attributes).width)
    }
}
