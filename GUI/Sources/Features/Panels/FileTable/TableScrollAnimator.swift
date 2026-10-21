// TableScrollAnimator.swift
// MiMiNavigator
//
// Keeps keyboard navigation aligned with the native file-table viewport.

import AppKit
import SwiftUI

// MARK: - Table Scroll Animator
@MainActor
enum TableScrollAnimator {
    static func scroll(
        _ scrollView: NSScrollView,
        toRow index: Int,
        fromRow previousIndex: Int?,
        kind: TableKeyboardNavigation.NavigationKind,
        animated: Bool = true
    ) {
        let clipView = scrollView.contentView
        let visibleHeight = clipView.bounds.height
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        guard visibleHeight > 0, documentHeight > 0 else { return }
        let rowHeight = FilePanelStyle.rowHeight
        let rowTop = TableHeaderStyle.height + 2 + CGFloat(index) * rowHeight
        let rowBottom = rowTop + rowHeight
        let currentY = clipView.bounds.minY
        let maxY = max(0, documentHeight - visibleHeight)
        let margin = min(rowHeight / 3, 7)
        let targetY: CGFloat
        switch kind {
            case .edge:
                targetY = index == 0 ? 0 : maxY
            case .page:
                if let previousIndex,
                   rowTop - CGFloat(index - previousIndex) * rowHeight >= currentY,
                   rowTop - CGFloat(index - previousIndex) * rowHeight < currentY + visibleHeight {
                    targetY = currentY + CGFloat(index - previousIndex) * rowHeight
                } else {
                    targetY = nearestOffset(rowTop: rowTop, rowBottom: rowBottom, currentY: currentY, visibleHeight: visibleHeight, margin: margin)
                }
            case .row:
                targetY = nearestOffset(rowTop: rowTop, rowBottom: rowBottom, currentY: currentY, visibleHeight: visibleHeight, margin: margin)
        }
        let clampedY = min(max(0, targetY), maxY)
        guard abs(clampedY - currentY) > 0.5 else { return }
        let destination = NSPoint(x: clipView.bounds.minX, y: clampedY)
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            if abs(clampedY - currentY) > rowHeight * 2 {
                let approachY = min(max(0, clampedY - (clampedY > currentY ? 10 : -10)), maxY)
                clipView.scroll(to: NSPoint(x: destination.x, y: approachY))
                scrollView.reflectScrolledClipView(clipView)
            }
            NSAnimationContext.animate(.snappy(duration: 0.18, extraBounce: 0.03)) {
                clipView.animator().setBoundsOrigin(destination)
            } completion: {
                Task { @MainActor in
                    scrollView.reflectScrolledClipView(clipView)
                }
            }
        } else {
            clipView.scroll(to: destination)
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    // MARK: - Nearest Visible Offset
    private static func nearestOffset(rowTop: CGFloat, rowBottom: CGFloat, currentY: CGFloat, visibleHeight: CGFloat, margin: CGFloat) -> CGFloat {
        if rowTop < currentY + margin { return rowTop - margin }
        if rowBottom > currentY + visibleHeight - margin { return rowBottom - visibleHeight + margin }
        return currentY
    }
}
