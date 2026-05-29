// BreadCrumbView+Segments.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 29.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Visible breadcrumb segment calculation and path shortening.

import SwiftUI

// MARK: - BreadCrumbView Segment Model
extension BreadCrumbView {
    struct DisplaySegment: Identifiable {
        let id = UUID()
        let text: String
        let fullName: String
        let originalIndex: Int
        let isEnvironmentVariable: Bool
        let showsSeparatorBefore: Bool
        let isCollapsedChain: Bool
        var isTruncated: Bool { text != fullName }
    }
}

// MARK: - BreadCrumbView Segment Layout
extension BreadCrumbView {
    func visibleSegments(for availableWidth: CGFloat) -> [DisplaySegment] {
        let components = pathComponents
        guard !components.isEmpty else { return [] }
        if components.count == 1 {
            return [displaySegment(for: components[0], index: 0, showsSeparatorBefore: false)]
        }
        let charWidth: CGFloat = 7.5
        let separatorWidth: CGFloat = 10
        let totalSepWidth = CGFloat(components.count - 1) * separatorWidth
        let budgetForText = availableWidth - totalSepWidth - 16
        let widths = components.map { CGFloat($0.text.count) * charWidth }
        let totalWidth = widths.reduce(0, +)
        if totalWidth <= budgetForText {
            return components.enumerated().map { displaySegment(for: $0.element, index: $0.offset, components: components) }
        }
        if let collapsed = contextualCollapsedSegments(components: components, budgetForText: budgetForText, charWidth: charWidth) {
            return collapsed
        }
        var segs = components.enumerated().map { i, component in
            BreadCrumbMeasuredSegment(
                index: i,
                name: component.text,
                display: component.text,
                width: widths[i],
                priority: truncPriority(index: i, total: components.count, len: component.text.count)
            )
        }
        var used = totalWidth
        while used > budgetForText {
            guard let idx = segs.enumerated().filter({ $0.element.display.count > 3 }).max(by: { $0.element.priority < $1.element.priority })?.offset else { break }
            let old = segs[idx]
            let newDisplay = truncMiddle(old.display, maxLen: max(3, old.display.count - 4))
            let newWidth = CGFloat(newDisplay.count) * charWidth
            used -= old.width - newWidth
            segs[idx].display = newDisplay
            segs[idx].width = newWidth
            segs[idx].priority = 0
        }
        return segs.map {
            DisplaySegment(
                text: $0.display,
                fullName: $0.name,
                originalIndex: $0.index,
                isEnvironmentVariable: components[$0.index].isEnvironmentVariable,
                showsSeparatorBefore: showsSeparatorBefore(index: $0.index, components: components),
                isCollapsedChain: false
            )
        }
    }

    private func displaySegment(
        for component: BreadCrumbDisplayComponent,
        index: Int,
        components: [BreadCrumbDisplayComponent]? = nil,
        showsSeparatorBefore forcedSeparator: Bool? = nil
    ) -> DisplaySegment {
        DisplaySegment(
            text: component.text,
            fullName: component.text,
            originalIndex: index,
            isEnvironmentVariable: component.isEnvironmentVariable,
            showsSeparatorBefore: forcedSeparator ?? components.map { showsSeparatorBefore(index: index, components: $0) } ?? false,
            isCollapsedChain: false
        )
    }

    private func contextualCollapsedSegments(
        components: [BreadCrumbDisplayComponent],
        budgetForText: CGFloat,
        charWidth: CGFloat
    ) -> [DisplaySegment]? {
        guard components.count > 6 else { return nil }
        let budgets = contextualBudgets(for: components.count)
        for budget in budgets {
            if let result = collapsedSegments(
                components: components,
                leadingCount: budget.leading,
                trailingCount: budget.trailing,
                budgetForText: budgetForText,
                charWidth: charWidth
            ) {
                return result
            }
        }
        return nil
    }

    private func contextualBudgets(for count: Int) -> [(leading: Int, trailing: Int)] {
        let leadingMax = min(4, count - 3)
        let trailingMax = min(6, count - 3)
        var result: [(leading: Int, trailing: Int)] = []
        for leading in stride(from: leadingMax, through: 2, by: -1) {
            for trailing in stride(from: trailingMax, through: 2, by: -1) {
                guard leading + trailing < count else { continue }
                result.append((leading, trailing))
            }
        }
        return result
    }

    private func collapsedSegments(
        components: [BreadCrumbDisplayComponent],
        leadingCount: Int,
        trailingCount: Int,
        budgetForText: CGFloat,
        charWidth: CGFloat
    ) -> [DisplaySegment]? {
        let hiddenStart = leadingCount
        let hiddenEnd = components.count - trailingCount
        guard hiddenStart < hiddenEnd else { return nil }
        let hiddenRange = hiddenStart..<hiddenEnd
        let hiddenText = components[hiddenRange].map(\.text).joined(separator: " / ")
        let indexes = Array(0..<leadingCount) + [-1] + Array(hiddenEnd..<components.count)
        var textByIndex = Dictionary(uniqueKeysWithValues: indexes.compactMap { index -> (Int, String)? in
            guard index >= 0 else { return (-1, "...") }
            return (index, components[index].text)
        })
        if fits(indexes: indexes, textByIndex: textByIndex, budgetForText: budgetForText, charWidth: charWidth) {
            return makeCollapsedSegments(components: components, indexes: indexes, textByIndex: textByIndex, hiddenRange: hiddenRange, hiddenText: hiddenText)
        }
        for index in shrinkOrder(indexes: indexes, components: components) {
            guard index >= 0, let text = textByIndex[index], text.count > 8 else { continue }
            textByIndex[index] = truncMiddle(text, maxLen: max(8, min(12, text.count - 4)))
            if fits(indexes: indexes, textByIndex: textByIndex, budgetForText: budgetForText, charWidth: charWidth) {
                return makeCollapsedSegments(components: components, indexes: indexes, textByIndex: textByIndex, hiddenRange: hiddenRange, hiddenText: hiddenText)
            }
        }
        return nil
    }

    private func fits(indexes: [Int], textByIndex: [Int: String], budgetForText: CGFloat, charWidth: CGFloat) -> Bool {
        let textWidth = indexes.reduce(CGFloat(0)) { total, index in
            total + CGFloat((textByIndex[index] ?? "").count) * charWidth
        }
        return textWidth <= max(budgetForText, 72)
    }

    private func makeCollapsedSegments(
        components: [BreadCrumbDisplayComponent],
        indexes: [Int],
        textByIndex: [Int: String],
        hiddenRange: Range<Int>,
        hiddenText: String
    ) -> [DisplaySegment] {
        indexes.map { index in
            if index == -1 {
                return DisplaySegment(
                    text: "...",
                    fullName: hiddenText,
                    originalIndex: hiddenRange.upperBound - 1,
                    isEnvironmentVariable: false,
                    showsSeparatorBefore: components[hiddenRange.lowerBound - 1].text != "/",
                    isCollapsedChain: true
                )
            }
            return DisplaySegment(
                text: textByIndex[index] ?? components[index].text,
                fullName: components[index].text,
                originalIndex: index,
                isEnvironmentVariable: components[index].isEnvironmentVariable,
                showsSeparatorBefore: showsSeparatorBefore(index: index, components: components),
                isCollapsedChain: false
            )
        }
    }

    private func shrinkOrder(indexes: [Int], components: [BreadCrumbDisplayComponent]) -> [Int] {
        indexes
            .filter { $0 >= 0 }
            .sorted { lhs, rhs in
                components[lhs].text.count > components[rhs].text.count
            }
    }

    private func showsSeparatorBefore(index: Int, components: [BreadCrumbDisplayComponent]) -> Bool {
        index > 0 && components[index - 1].text != "/"
    }

    private func truncPriority(index: Int, total: Int, len: Int) -> Int {
        guard index != 0 && index != total - 1 else { return 0 }
        return len * 10
    }

    private func truncMiddle(_ s: String, maxLen: Int) -> String {
        guard s.count > maxLen, maxLen >= 3 else { return s }
        let half = (maxLen - 1) / 2
        return "\(s.prefix(half))...\(s.suffix(half))"
    }
}

// MARK: - BreadCrumb Measured Segment
private struct BreadCrumbMeasuredSegment {
    let index: Int
    let name: String
    var display: String
    var width: CGFloat
    var priority: Int
}
