// AdaptiveThumbnailLayout.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.09.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Row layout that lets landscape thumbnails span adjacent cells.

import SwiftUI

// MARK: - ThumbnailColumnSpanKey

struct ThumbnailColumnSpanKey: LayoutValueKey {
    static let defaultValue = 1
}

// MARK: - AdaptiveThumbnailLayout

struct AdaptiveThumbnailLayout: SwiftUI.Layout {
    let cellSize: CGFloat
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat

    // MARK: - Size That Fits

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: SwiftUI.LayoutSubviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? cellSize
        return layoutPlan(width: width, subviews: subviews).size
    }

    // MARK: - Place Subviews

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: SwiftUI.LayoutSubviews,
        cache: inout ()
    ) {
        let plan = layoutPlan(width: bounds.width, subviews: subviews)
        for (index, frame) in plan.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    // MARK: - Layout Plan

    private func layoutPlan(
        width: CGFloat,
        subviews: SwiftUI.LayoutSubviews
    ) -> (size: CGSize, frames: [CGRect]) {
        let columnCount = max(1, Int((width + columnSpacing) / (cellSize + columnSpacing)))
        let occupiedWidth = CGFloat(columnCount) * cellSize + CGFloat(columnCount - 1) * columnSpacing
        let columnWidth = cellSize + max(0, width - occupiedWidth) / CGFloat(columnCount)
        var frames: [CGRect] = []
        var rowItems: [(index: Int, column: Int, span: Int, size: CGSize)] = []
        var currentColumn = 0
        var y: CGFloat = 0
        func flushRow() {
            guard !rowItems.isEmpty else { return }
            let rowHeight = rowItems.map(\.size.height).max() ?? 0
            for item in rowItems {
                frames[item.index] = CGRect(
                    x: CGFloat(item.column) * (columnWidth + columnSpacing),
                    y: y,
                    width: item.size.width,
                    height: item.size.height
                )
            }
            y += rowHeight + rowSpacing
            rowItems.removeAll(keepingCapacity: true)
            currentColumn = 0
        }
        for (index, subview) in subviews.enumerated() {
            let requestedSpan = subview[ThumbnailColumnSpanKey.self]
            let span = min(columnCount, max(1, requestedSpan))
            if currentColumn + span > columnCount { flushRow() }
            let itemWidth = CGFloat(span) * columnWidth + CGFloat(span - 1) * columnSpacing
            let itemSize = subview.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            frames.append(.zero)
            rowItems.append((index, currentColumn, span, CGSize(width: itemWidth, height: itemSize.height)))
            currentColumn += span
            if currentColumn == columnCount { flushRow() }
        }
        flushRow()
        let height = max(0, y - rowSpacing)
        return (CGSize(width: width, height: height), frames)
    }
}
