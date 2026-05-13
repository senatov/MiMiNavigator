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
        default:
            return percentileContentWidth(measuredWidths, for: column)
        }
    }

    // MARK: - Percentile Content Width
    /// 85th-percentile of trimmed widths + insets + per-column reserve.
    /// Simple, predictable, tight fit without bloating short columns.
    private static func percentileContentWidth(_ measuredWidths: [CGFloat], for column: ColumnID) -> CGFloat {
        let trimmed = trimmedWidths(measuredWidths, trimFraction: 0.10)
        guard !trimmed.isEmpty else { return ColumnAutoFitMetrics.emptyColumnWidth }
        let sorted = trimmed.sorted()
        let p85Index = min(Int(ceil(Double(sorted.count) * 0.85)) - 1, sorted.count - 1)
        let percentileWidth = sorted[max(0, p85Index)]
        let extraWidth = ColumnWidthPolicy.extraReserveWidth(for: column)
        return ceil(percentileWidth + 2 * ColumnAutoFitMetrics.measuredContentInset + extraWidth)
    }

    // MARK: - Name Content Width
    private static func nameContentWidth(_ measuredWidths: [CGFloat]) -> CGFloat {
        ceil(percentileContentWidth(measuredWidths, for: .name) + ColumnAutoFitMetrics.nameIconAndInsetWidth)
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
        // minWidth is the real minimum — not defaultWidth which is just the initial pre-autofit value
        let floor = max(column.minWidth, ColumnAutoFitMetrics.emptyColumnWidth)
        var clampedWidth = width.clamped(to: floor...ColumnWidthPolicy.effectiveMaxWidth(for: column))
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
            return max(fallback, column.minWidth)
        }
        log.verbose("[AutoFit] contentWidth \(column.rawValue) empty")
        return max(ColumnAutoFitMetrics.emptyColumnWidth, column.minWidth)
    }

    // MARK: - Text Samples
    /// For large directories, sampling avoids measuring 19k+ strings.
    /// Takes first 200 + every Nth to cover outliers without full enumeration.
    private static let samplingThreshold = 500

    private static func textSamples(_ column: ColumnID, files: [CustomFile]) -> ([String], NSFont) {
        let sampled = sampledFiles(files)
        switch column {
        case .name:
            return (sampled.map(\.nameStr), .systemFont(ofSize: 14, weight: .light))
        case .size:
            return (sampled.map(\.displaySizeFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .dateModified:
            return (sampled.map(\.modifiedDateFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .kind:
            return (sampled.map(\.kindFormatted), .systemFont(ofSize: 12))
        case .permissions:
            return (sampled.map(\.permissionsFormatted), .monospacedSystemFont(ofSize: 11, weight: .regular))
        case .owner:
            return (sampled.map(\.ownerFormatted), .systemFont(ofSize: 12, weight: .regular))
        case .childCount:
            return (sampled.map(\.childCountFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .dateCreated:
            return (sampled.map(\.creationDateFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .dateLastOpened:
            return (sampled.map(\.lastOpenedFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .dateAdded:
            return (sampled.map(\.dateAddedFormatted), .monospacedDigitSystemFont(ofSize: 12, weight: .regular))
        case .group:
            return (sampled.map(\.groupNameFormatted), .systemFont(ofSize: 12))
        }
    }


    /// Deterministic sampling: first 200 items + every Nth for big dirs.
    /// Guarantees O(500) max samples regardless of directory size.
    private static func sampledFiles(_ files: [CustomFile]) -> [CustomFile] {
        guard files.count > samplingThreshold else { return files }
        let headCount = 200
        let head = Array(files.prefix(headCount))
        let remaining = files.dropFirst(headCount)
        let stride = max(1, remaining.count / (samplingThreshold - headCount))
        var sampled = head
        for (idx, file) in remaining.enumerated() {
            if idx % stride == 0 {
                sampled.append(file)
            }
        }
        return sampled
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
