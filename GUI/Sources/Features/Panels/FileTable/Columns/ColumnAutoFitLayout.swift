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
    static let ownerColumnInsetBoost: CGFloat = 8
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
        let result = max(calculatedNameWidth, remainder)
        if result > remainder + ColumnAutoFitMetrics.edgeAlignmentEpsilon {
            log.debug("[AutoFit] fixed columns overflow right name=\(pt(calculatedNameWidth)) remainder=\(pt(remainder))")
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
