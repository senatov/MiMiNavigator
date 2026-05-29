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
        if let collapsed = collapsedChainSegments(components: components, budgetForText: budgetForText, charWidth: charWidth) {
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

    private func collapsedChainSegments(
        components: [BreadCrumbDisplayComponent],
        budgetForText: CGFloat,
        charWidth: CGFloat
    ) -> [DisplaySegment]? {
        guard components.count > 2 else { return nil }
        let hiddenRange = 1..<(components.count - 1)
        let hiddenText = components[hiddenRange].map(\.text).joined(separator: " / ")
        let collapsedText = "..."
        let keptWidth = CGFloat(components[0].text.count + collapsedText.count + components.last!.text.count) * charWidth
        guard keptWidth <= max(budgetForText, 48) else { return nil }
        return [
            displaySegment(for: components[0], index: 0, showsSeparatorBefore: false),
            DisplaySegment(
                text: collapsedText,
                fullName: hiddenText,
                originalIndex: hiddenRange.upperBound - 1,
                isEnvironmentVariable: false,
                showsSeparatorBefore: components[0].text != "/",
                isCollapsedChain: true
            ),
            displaySegment(for: components.last!, index: components.count - 1, showsSeparatorBefore: true)
        ]
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
