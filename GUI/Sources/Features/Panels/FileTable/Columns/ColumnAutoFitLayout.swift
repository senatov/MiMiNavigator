// ColumnAutoFitLayout.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.

import CoreGraphics
import Foundation

// MARK: - Fitted Column
struct FittedColumn {
    let id: ColumnID
    var width: CGFloat
}

// MARK: - Column Auto Fit Result
struct ColumnAutoFitResult {
    let fixedColumns: [FittedColumn]
    let nameWidth: CGFloat
}

// MARK: - Column Auto Fit Metrics
enum ColumnAutoFitMetrics {
    static let dividerWidth: CGFloat = 14
    static let emptyColumnWidth: CGFloat = 24
    static let measuredContentInset: CGFloat = 5
    static let trailingPanelInset: CGFloat = 17
    static let nameIconAndInsetWidth: CGFloat = 34
    static let ownerColumnInsetBoost: CGFloat = 4
    static let textRenderingReserve: CGFloat = 2
    static let edgeAlignmentEpsilon: CGFloat = 0.5
}

// MARK: - Column Auto Fit Layout
enum ColumnAutoFitLayout {
    // MARK: - Name Width
    static func nameWidth(calculatedNameWidth: CGFloat, containerWidth: CGFloat, fixedColumns: [FittedColumn]) -> CGFloat {
        let remainder = containerWidth
            - totalFixedWidth(fixedColumns)
            - dividerTotal(for: fixedColumns.count)
            - ColumnAutoFitMetrics.trailingPanelInset
        let minimumNameWidth: CGFloat = 60
        let result = max(minimumNameWidth, remainder)
        if calculatedNameWidth > result + ColumnAutoFitMetrics.edgeAlignmentEpsilon {
            log.debug("[AutoFit] name truncated to fit panel measured=\(pt(calculatedNameWidth)) applied=\(pt(result))")
        }
        if remainder < minimumNameWidth {
            log.debug("[AutoFit] fixed columns exceed panel width remainder=\(pt(remainder))")
        }
        return result
    }

    // MARK: - Divider Total
    static func dividerTotal(for fixedColumnCount: Int) -> CGFloat {
        CGFloat(fixedColumnCount) * ColumnAutoFitMetrics.dividerWidth
    }

    // MARK: - Total Fixed Width
    static func totalFixedWidth(_ columns: [FittedColumn]) -> CGFloat {
        columns.reduce(CGFloat.zero) { partialWidth, fittedColumn in
            partialWidth + fittedColumn.width
        }
    }

    // MARK: - Points
    static func pt(_ value: CGFloat) -> String {
        String(format: "%.1fpt", value)
    }
}
