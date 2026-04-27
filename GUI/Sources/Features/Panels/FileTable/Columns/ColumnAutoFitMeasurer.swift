// ColumnAutoFitMeasurer.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FileModelKit
import Foundation

// MARK: - Column Auto Fit Measurer
enum ColumnAutoFitMeasurer {
    private static let correctiveClippingThreshold: CGFloat = 0.15

    // MARK: - Content Width
    static func contentWidth(for column: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(column, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else { return fallbackWidth(for: column) }
        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let fittedWidth = fittedContentWidth(for: column, measuredWidths: measuredWidths)
        let width = clamped(width: fittedWidth, column: column, meaningfulCount: meaningfulTexts.count, totalCount: texts.count)
        log.verbose("[AutoFit] contentWidth \(column.rawValue) \(ColumnAutoFitLayout.pt(width))")
        return width
    }

    // MARK: - Corrective Content Width
    static func correctiveContentWidth(for column: ColumnID, files: [CustomFile]) -> CGFloat {
        let (texts, font) = textSamples(column, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else { return fallbackWidth(for: column) }
        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let percentileWidth = clippingSafePercentileWidth(measuredWidths)
        let fittedWidth = requiredContentWidth(for: column, measuredWidth: percentileWidth)
        return clamped(width: fittedWidth, column: column, meaningfulCount: meaningfulTexts.count, totalCount: texts.count)
    }

    // MARK: - Measured Clipping Ratio
    static func measuredClippingRatio(for column: ColumnID, files: [CustomFile], fittedWidth: CGFloat) -> CGFloat {
        let (texts, font) = textSamples(column, files: files)
        let meaningfulTexts = texts.filter(isRealContent)
        guard !meaningfulTexts.isEmpty else { return .zero }
        let measuredWidths = measuredTextWidths(meaningfulTexts, font: font)
        let clippedCount = measuredWidths.filter { measuredWidth in
            requiredContentWidth(for: column, measuredWidth: measuredWidth) > fittedWidth + ColumnAutoFitMetrics.edgeAlignmentEpsilon
        }.count
        return CGFloat(clippedCount) / CGFloat(measuredWidths.count)
    }

    // MARK: - Fitted Content Width
    private static func fittedContentWidth(for column: ColumnID, measuredWidths: [CGFloat]) -> CGFloat {
        switch column {
        case .name:
            return nameContentWidth(measuredWidths)
        case .owner:
            return ownerContentWidth(measuredWidths)
        case .size:
            return sizeColumnContentWidth(measuredWidths)
        default:
            return weightedAverageContentWidth(measuredWidths, for: column)
        }
    }

    // MARK: - Weighted Average
    private static func weightedAverageContentWidth(_ measuredWidths: [CGFloat], for column: ColumnID) -> CGFloat {
        let trimmed = trimmedWidths(measuredWidths, trimFraction: 0.10)
        guard !trimmed.isEmpty else { return ColumnAutoFitMetrics.emptyColumnWidth }
        let sumW = trimmed.reduce(0, +)
        guard sumW > 0 else { return ColumnAutoFitMetrics.emptyColumnWidth }
        let sumWW = trimmed.reduce(0) { $0 + $1 * $1 }
        let weighted = sumWW / sumW
        let extraWidth = ColumnWidthPolicy.extraReserveWidth(for: column)
        return ceil(weighted + 2 * ColumnAutoFitMetrics.measuredContentInset + extraWidth)
    }

    // MARK: - Name Content Width
    private static func nameContentWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        ceil(weightedAverageContentWidth(measuredWidths, for: .name) + ColumnAutoFitMetrics.nameIconAndInsetWidth)
    }

    // MARK: - Size Content Width
    private static func sizeColumnContentWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        let trimmed = trimmedWidths(measuredWidths, trimFraction: 0.10)
        guard !trimmed.isEmpty else { return ColumnAutoFitMetrics.emptyColumnWidth }
        let sorted = trimmed.sorted()
        let p85Index = min(Int(ceil(Double(sorted.count) * 0.85)) - 1, sorted.count - 1)
        let percentileWidth = sorted[max(0, p85Index)]
        let extraWidth = ColumnWidthPolicy.extraReserveWidth(for: .size)
        return ceil(percentileWidth + 2 * ColumnAutoFitMetrics.measuredContentInset + extraWidth)
    }

    // MARK: - Owner Content Width
    private static func ownerContentWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        guard let maximumWidth = measuredWidths.max() else { return ColumnAutoFitMetrics.emptyColumnWidth }
        return ceil(maximumWidth + 2 * ColumnAutoFitMetrics.measuredContentInset + ColumnAutoFitMetrics.ownerColumnInsetBoost)
    }

    // MARK: - Required Content Width
    private static func requiredContentWidth(for column: ColumnID, measuredWidth: CGFloat) -> CGFloat {
        switch column {
        case .name:
            return ceil(measuredWidth + 2 * ColumnAutoFitMetrics.measuredContentInset + ColumnAutoFitMetrics.nameIconAndInsetWidth)
        case .owner:
            return ceil(measuredWidth + 2 * ColumnAutoFitMetrics.measuredContentInset + ColumnAutoFitMetrics.ownerColumnInsetBoost)
        default:
            return ceil(measuredWidth + 2 * ColumnAutoFitMetrics.measuredContentInset + ColumnWidthPolicy.extraReserveWidth(for: column))
        }
    }

    // MARK: - Clamp Width
    private static func clamped(width: CGFloat, column: ColumnID, meaningfulCount: Int, totalCount: Int) -> CGFloat {
        guard column != .name else { return max(width, ColumnAutoFitMetrics.emptyColumnWidth) }
        var clampedWidth = width.clamped(to: ColumnAutoFitMetrics.emptyColumnWidth...ColumnWidthPolicy.effectiveMaxWidth(for: column))
        if column == .size && meaningfulCount < totalCount {
            clampedWidth = max(clampedWidth, ColumnWidthPolicy.sizeColumnFallbackWidth())
        }
        return clampedWidth
    }

    // MARK: - Fallback Width
    private static func fallbackWidth(for column: ColumnID) -> CGFloat {
        if column == .size {
            let fallback = ColumnWidthPolicy.sizeColumnFallbackWidth()
            log.verbose("[AutoFit] contentWidth \(column.rawValue) fallback=\(ColumnAutoFitLayout.pt(fallback))")
            return fallback
        }
        log.verbose("[AutoFit] contentWidth \(column.rawValue) empty")
        return ColumnAutoFitMetrics.emptyColumnWidth
    }

    // MARK: - Text Samples
    private static func textSamples(_ column: ColumnID, files: [CustomFile]) -> ([String], NSFont) {
        switch column {
        case .name:
            return (files.map(\.nameStr), .systemFont(ofSize: 14, weight: .light))
        case .size:
            return (files.map(\.displaySizeFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .dateModified:
            return (files.map(\.modifiedDateFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .kind:
            return (files.map(\.kindFormatted), .systemFont(ofSize: 12))
        case .permissions:
            return (files.map(\.permissionsFormatted), .monospacedSystemFont(ofSize: 11, weight: .regular))
        case .owner:
            return (files.map(\.ownerFormatted), .systemFont(ofSize: 12, weight: .regular))
        case .childCount:
            return (files.map(\.childCountFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .dateCreated:
            return (files.map(\.creationDateFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .dateLastOpened:
            return (files.map(\.lastOpenedFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .dateAdded:
            return (files.map(\.dateAddedFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .group:
            return (files.map(\.groupNameFormatted), .systemFont(ofSize: 12))
        }
    }

    // MARK: - Text Widths
    private static func measuredTextWidths(_ texts: [String], font: NSFont) -> [CGFloat] {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return texts.map { ($0 as NSString).size(withAttributes: attributes).width }
    }

    // MARK: - Real Content
    private static func isRealContent(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let stripped = text.trimmingCharacters(in: .whitespaces)
        return !stripped.allSatisfy { character in
            character == "-" || character == "\u{2013}" || character == "\u{2014}" || character == "\u{2015}"
        }
    }

    // MARK: - Clipping Percentile
    private static func clippingSafePercentileWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        guard !measuredWidths.isEmpty else { return ColumnAutoFitMetrics.emptyColumnWidth }
        let sortedWidths = measuredWidths.sorted()
        let percentileIndex = Int(floor(CGFloat(sortedWidths.count - 1) * (1 - correctiveClippingThreshold)))
        return sortedWidths[max(0, min(percentileIndex, sortedWidths.count - 1))]
    }

    // MARK: - Trimmed Widths
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

private extension CGFloat {
    // MARK: - Clamped
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
