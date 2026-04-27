// ColumnAutoFitter.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.

import FileModelKit
import Foundation

// MARK: - Column Auto Fitter
enum ColumnAutoFitter {
    private static let widthStabilityEpsilon: CGFloat = 1
    private static let correctiveClippingThreshold: CGFloat = 0.15

    // MARK: - Auto Fit All
    static func autoFitAll(layout: ColumnLayoutModel, files: [CustomFile]) {
        log.verbose("[AutoFit] autoFitAll start container=\(ColumnAutoFitLayout.pt(layout.containerWidth)) files=\(files.count) fixedCols=\(layout.fixedColumns.count)")
        guard let result = makeAutoFitResult(layout: layout, files: files) else {
            log.verbose("[AutoFit] autoFitAll skip no result")
            return
        }
        guard needsUpdate(layout: layout, result: result) else {
            log.verbose("[AutoFit] autoFitAll skip widths stable")
            return
        }
        let colSummary = result.fixedColumns.map { "\($0.id.rawValue)=\(ColumnAutoFitLayout.pt($0.width))" }.joined(separator: " ")
        log.info("[AutoFit] APPLY name=\(ColumnAutoFitLayout.pt(result.nameWidth)) \(colSummary)")
        apply(result: result, to: layout)
    }

    // MARK: - Result
    private static func makeAutoFitResult(layout: ColumnLayoutModel, files: [CustomFile]) -> ColumnAutoFitResult? {
        guard layout.containerWidth > 0, !files.isEmpty else { return nil }
        let fixedSpecs = layout.fixedColumns
        var fixedColumns = measuredFixedColumns(from: fixedSpecs, files: files)
        let nameWidth = ColumnAutoFitMeasurer.contentWidth(for: .name, files: files)
        for _ in 0..<2 {
            guard needsCorrectivePass(columns: fixedSpecs, fittedColumns: fixedColumns, files: files) else { break }
            applyCorrectivePass(columns: fixedSpecs, fittedColumns: &fixedColumns, files: files)
        }
        let finalNameWidth = ColumnAutoFitLayout.nameWidth(
            calculatedNameWidth: nameWidth,
            containerWidth: layout.containerWidth,
            fixedColumns: fixedColumns
        )
        return ColumnAutoFitResult(fixedColumns: fixedColumns, nameWidth: finalNameWidth)
    }

    // MARK: - Fixed Columns
    private static func measuredFixedColumns(from columns: [ColumnSpec], files: [CustomFile]) -> [FittedColumn] {
        columns.map { spec in
            FittedColumn(id: spec.id, width: ColumnAutoFitMeasurer.contentWidth(for: spec.id, files: files))
        }
    }

    // MARK: - Corrective Pass
    private static func needsCorrectivePass(columns: [ColumnSpec], fittedColumns: [FittedColumn], files: [CustomFile]) -> Bool {
        for column in columns {
            guard let fittedColumn = fittedColumns.first(where: { $0.id == column.id }) else { continue }
            let clippingRatio = ColumnAutoFitMeasurer.measuredClippingRatio(
                for: column.id,
                files: files,
                fittedWidth: fittedColumn.width
            )
            if clippingRatio > correctiveClippingThreshold {
                return true
            }
        }
        return false
    }

    // MARK: - Apply Corrective Pass
    private static func applyCorrectivePass(columns: [ColumnSpec], fittedColumns: inout [FittedColumn], files: [CustomFile]) {
        for index in fittedColumns.indices {
            let columnID = fittedColumns[index].id
            guard columns.contains(where: { $0.id == columnID }) else { continue }
            fittedColumns[index].width = ColumnAutoFitMeasurer.correctiveContentWidth(for: columnID, files: files)
        }
    }

    // MARK: - Needs Update
    private static func needsUpdate(layout: ColumnLayoutModel, result: ColumnAutoFitResult) -> Bool {
        let nameDelta = abs(layout.nameWidth - result.nameWidth)
        let isNameStable = nameDelta < widthStabilityEpsilon
        let areFixedColumnsStable = result.fixedColumns.allSatisfy { fittedColumn in
            guard let index = layout.columns.firstIndex(where: { $0.id == fittedColumn.id }) else { return true }
            return abs(layout.columns[index].width - fittedColumn.width) < widthStabilityEpsilon
        }
        return !isNameStable || !areFixedColumnsStable
    }

    // MARK: - Apply
    private static func apply(result: ColumnAutoFitResult, to layout: ColumnLayoutModel) {
        let widths = Dictionary(uniqueKeysWithValues: result.fixedColumns.map { ($0.id, $0.width) })
        layout.applyAutoFitWidths(widths, nameWidth: result.nameWidth)
        layout.autoFitGeneration += 1
    }
}
