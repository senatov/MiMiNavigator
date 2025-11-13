//
//  SplitContainerCoordinator.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.11.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import AppKit
import SwiftUI

@MainActor
final class SplitContainerCoordinator<Left: View, Right: View>: NSObject, NSSplitViewDelegate {
    var parent: SplitContainer<Left, Right>
    // Re-entrancy guards to prevent feedback loops
    var isProgrammatic: Bool = false
    var lastSetPosition: CGFloat = .nan

    init(_ parent: SplitContainer<Left, Right>) {
        self.parent = parent
    }

    // MARK: - Min coordinate constraint
    func splitView(
        _ splitView: NSSplitView,
        constrainMinCoordinate proposedMinimumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        log.debug(#function)
        // Respect system proposal, but never allow the left panel to be smaller than our minimum
        return max(proposedMinimumPosition, parent.minPanelWidth)
    }

    // MARK: - Max coordinate constraint
    func splitView(
        _ splitView: NSSplitView,
        constrainMaxCoordinate proposedMaximumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        // Ensure the right panel also respects the minimum width when the divider moves right
        let total = splitView.bounds.width
        let maxAllowed = total - parent.minPanelWidth - splitView.dividerThickness
        return min(proposedMaximumPosition, maxAllowed)
    }

    // MARK: - Enlarge effective divider rect to make double-click detection less finicky
    func splitView(
        _ splitView: NSSplitView,
        effectiveRect proposedEffectiveRect: NSRect,
        forDrawnRect drawnRect: NSRect,
        ofDividerAt dividerIndex: Int
    ) -> NSRect {
        log.debug(#function)
        return drawnRect.insetBy(dx: -3, dy: -6)
    }

    // MARK: - Persist user-driven divider drags
    func splitViewDidResizeSubviews(_ notification: Notification) {
        log.debug(#function)
        guard
            let splitView = notification.object as? NSSplitView,
            !isProgrammatic,
            let left = splitView.arrangedSubviews.first
        else { return }

        let total = max(splitView.bounds.width, 1)
        let scale =
            splitView.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0

        // Snap the measured width to pixel grid
        let measured = left.frame.width
        let snapped = (measured * scale).rounded() / scale

        // Respect min widths via the same clamp helper used elsewhere
        let clamped = parent.clampLeftWidth(
            snapped,
            totalWidth: total,
            minPanelWidth: parent.minPanelWidth,
            dividerThickness: splitView.dividerThickness
        )

        // Update lastSetPosition and persist if it actually changed
        lastSetPosition = clamped
        if abs(parent.leftPanelWidth - clamped) >= 0.5 {
            parent.leftPanelWidth = clamped
            log.debug(
                "SplitContainer.drag measured=\(Int(measured)) snapped=\(Int(snapped)) clamped=\(Int(clamped)) total=\(Int(total))"
            )
        }
    }

    // MARK: - Handle double-click coming directly from SplitView subclass
    @objc func handleDoubleClickFromSplitView(_ sv: NSSplitView) {
        if SplitContainer<Left, Right>.verboseLogs {
            let leftMaxX = sv.arrangedSubviews.first?.frame.maxX ?? 0
            let drawn = NSRect(x: leftMaxX, y: 0, width: sv.dividerThickness, height: sv.bounds.height)
            let hit = drawn.insetBy(dx: -3, dy: -6)
            log.debug(
                "DC.fromSV start total=\(Int(sv.bounds.width)) drawn=\(NSStringFromRect(drawn)) hit=\(NSStringFromRect(hit))"
            )
        }

        let total = max(sv.bounds.width, 1)
        let desired = parent.clampLeftWidth(
            total / 2,
            totalWidth: total,
            minPanelWidth: parent.minPanelWidth,
            dividerThickness: sv.dividerThickness
        )

        isProgrammatic = true
        sv.setPosition(desired, ofDividerAt: 0)
        lastSetPosition = desired
        parent.leftPanelWidth = desired
        DispatchQueue.main.async { [weak self] in self?.isProgrammatic = false }
        log.debug("SplitContainer.doubleClick → 50/50 setPosition=\(Int(desired)) total=\(Int(total))")
    }
}
