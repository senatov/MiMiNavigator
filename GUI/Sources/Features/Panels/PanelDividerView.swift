// PanelDividerView.swift
// MiMiNavigator
//
// Extracted from PanelsRowView.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draggable divider between left/right panels with tooltip, pixel-snapping, 50/50 reset

import SwiftUI

// MARK: - Divider Drag State
struct DividerDragState {
    var isDragging: Bool = false
    var dragStartWidth: CGFloat = .nan
    var lastAppliedWidth: CGFloat = -1
    var dragGrabOffset: CGFloat = 0
    var dragPreviewLeft: CGFloat?
    var suppressDragUntilMouseUp: Bool = false
    // Tooltip
    var tooltipText: String = ""
    var tooltipPosition: CGPoint = .zero
    var isTooltipVisible: Bool = false
    var lastTooltipLeft: CGFloat = .nan
    // Throttling
    var lastLoggedWidth: CGFloat = -1
    var lastUILogTS: TimeInterval = 0
}

// MARK: - Divider Style Constants
enum PanelDividerStyle {
    static let hitAreaWidth: CGFloat = 24
    static let normalWidth: CGFloat = 2.0
    static let activeWidth: CGFloat = 5.0
    static let normalColor = Color(#colorLiteral(red: 0.42, green: 0.42, blue: 0.46, alpha: 0.55))
    static let activeColor = Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)).opacity(0.90)
    static let minPanelWidth: CGFloat = 80
}

// MARK: - Panel Divider View
/// Draggable divider line between panels. Supports drag resize, double-click 50/50, Option+click 50/50.
struct PanelDividerView: View {
    @Binding var leftPanelWidth: CGFloat
    @Binding var divider: DividerDragState
    let containerWidth: CGFloat
    let containerHeight: CGFloat

    var body: some View {
        let lineWidth = divider.isDragging ? PanelDividerStyle.activeWidth : PanelDividerStyle.normalWidth
        let lineColor = divider.isDragging ? PanelDividerStyle.activeColor : PanelDividerStyle.normalColor

        ZStack {
            // 3D highlight: 1pt white strip on left edge — simulates light source from top-left
            Rectangle()
                .fill(Color.white.opacity(divider.isDragging ? 0.0 : 0.80))
                .frame(width: 1, height: containerHeight)
                .offset(x: -0.5)
                .allowsHitTesting(false)
            // Main divider line
            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth, height: containerHeight)
                .shadow(color: Color.black.opacity(divider.isDragging ? 0.35 : 0.38), radius: divider.isDragging ? 5 : 4, x: 1, y: 0)
                .allowsHitTesting(false)
            // 3D shadow: 1pt dark strip on right edge — simulates depth
            Rectangle()
                .fill(Color.black.opacity(divider.isDragging ? 0.0 : 0.32))
                .frame(width: 1, height: containerHeight)
                .offset(x: 0.5)
                .allowsHitTesting(false)

            // Invisible hit area for comfortable grabbing
            Color.clear
                .frame(width: PanelDividerStyle.hitAreaWidth, height: containerHeight)
                .contentShape(Rectangle())
                .gesture(makeDragGesture())
                .simultaneousGesture(makeDoubleTapGesture())
                .simultaneousGesture(makeOptionTapGesture())
        }
        .frame(width: PanelDividerStyle.hitAreaWidth, height: containerHeight)
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .allowsHitTesting(true)
        .zIndex(10)
    }

    // MARK: - Drag Gesture

    private func makeDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                guard !divider.suppressDragUntilMouseUp else { return }

                if !divider.isDragging {
                    divider.isDragging = true
                    divider.dragPreviewLeft = leftPanelWidth
                    divider.dragGrabOffset = value.startLocation.x - (leftPanelWidth + PanelDividerStyle.hitAreaWidth / 2)
                    log.debug("[Divider] Drag begin")
                }

                let proposed = (value.location.x - divider.dragGrabOffset) - (PanelDividerStyle.hitAreaWidth / 2)
                let maxW = containerWidth - PanelDividerStyle.minPanelWidth - PanelDividerStyle.hitAreaWidth
                let clamped = max(PanelDividerStyle.minPanelWidth, min(proposed, maxW))
                let snapped = snapToPixelGrid(clamped)

                let moved = abs((divider.dragPreviewLeft ?? leftPanelWidth) - snapped) >= 0.5
                if moved {
                    divider.dragPreviewLeft = snapped
                }
                updateTooltip(snapped: snapped, locationY: value.location.y)
            }
            .onEnded { _ in
                commitDrag()
            }
    }

    // MARK: - Double Tap (50/50)

    private func makeDoubleTapGesture() -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                snapToCenter()
                log.debug("[Divider] Double-click → 50/50")
            }
    }

    // MARK: - Option+Tap (50/50)

    private func makeOptionTapGesture() -> some Gesture {
        TapGesture().modifiers(.option)
            .onEnded {
                snapToCenter()
                log.debug("[Divider] Option-tap → 50/50")
            }
    }

    // MARK: - Snap to Center

    func snapToCenter() {
        divider.suppressDragUntilMouseUp = true
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let halfCenter = (containerWidth / 2.0 * scale).rounded() / scale
        let halfLeft = halfCenter - PanelDividerStyle.hitAreaWidth / 2
        divider.lastAppliedWidth = halfLeft
        leftPanelWidth = halfLeft
        showTooltip(text: "50%", at: CGPoint(x: halfCenter, y: 46))

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            divider.isTooltipVisible = false
        }
    }

    // MARK: - Commit Drag

    private func commitDrag() {
        divider.suppressDragUntilMouseUp = false

        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            if let finalX = divider.dragPreviewLeft {
                if leftPanelWidth != finalX {
                    leftPanelWidth = finalX
                }
                divider.lastAppliedWidth = finalX
            }
            divider.dragGrabOffset = 0
            divider.dragStartWidth = .nan
            divider.isTooltipVisible = false
            divider.isDragging = false
            divider.lastTooltipLeft = .nan
            divider.dragPreviewLeft = nil
        }

        log.debug("[Divider] Commit → leftPanelWidth=\(Int(leftPanelWidth))")
    }

    // MARK: - Tooltip

    private func updateTooltip(snapped: CGFloat, locationY: CGFloat) {
        let delta = abs((divider.lastTooltipLeft.isNaN ? -9999 : divider.lastTooltipLeft) - snapped)
        guard delta >= 2 else { return }

        divider.lastTooltipLeft = snapped
        let centerX = snapped + PanelDividerStyle.hitAreaWidth / 2
        let percent = Int(((centerX / max(containerWidth, 1)) * 100.0).rounded()).clamped(to: 0...100)

        showTooltip(text: "\(percent)%", at: CGPoint(x: centerX, y: max(34, locationY - 70)))
    }

    private func showTooltip(text: String, at position: CGPoint) {
        divider.tooltipText = text
        divider.tooltipPosition = position
        divider.isTooltipVisible = true
    }

    // MARK: - Pixel Grid

    private func snapToPixelGrid(_ value: CGFloat) -> CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return (value * scale).rounded() / scale
    }
}

// MARK: - Comparable Extension
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
