// PanelDividerView.swift
// MiMiNavigator
//
// Extracted from PanelsRowView.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draggable divider between left/right panels with tooltip, pixel-snapping, 50/50 reset

import SwiftUI

// MARK: - Panel Divider View
/// Draggable divider line between panels. Supports drag resize, double-click 50/50, Option+click 50/50.
struct PanelDividerView: View {
    @Binding var leftPanelWidth: CGFloat
    @Binding var divider: DividerDragState
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    @State private var colorStore = ColorThemeStore.shared

    var body: some View {
        let lineWidth = divider.isDragging ? PanelDividerMetrics.activeWidth : PanelDividerMetrics.normalWidth
        let lineColor = divider.isDragging ? colorStore.activeTheme.dividerActiveColor : colorStore.activeTheme.dividerNormalColor

        ZStack {
            if divider.isDragging {
                activeDivider(height: containerHeight, lineWidth: lineWidth, color: lineColor)
            } else {
                inactiveGroove(height: containerHeight)
            }

            // Invisible hit area for comfortable grabbing
            Color.clear
                .frame(width: PanelDividerMetrics.hitAreaWidth, height: containerHeight)
                .contentShape(Rectangle())
                .gesture(makeDragGesture())
                .simultaneousGesture(makeDoubleTapGesture())
                .simultaneousGesture(makeOptionTapGesture())
        }
        .frame(width: PanelDividerMetrics.hitAreaWidth, height: containerHeight)
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
        .onHover { inside in
            updateCursor(inside)
        }
        .allowsHitTesting(true)
        .zIndex(10)
    }

    private func updateCursor(_ inside: Bool) {
        inside ? NSCursor.resizeLeftRight.set() : NSCursor.arrow.set()
    }

    // MARK: - Drag Gesture

    private func makeDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                guard !divider.suppressDragUntilMouseUp else { return }

                if !divider.isDragging {
                    divider.isDragging = true
                    divider.dragPreviewLeft = leftPanelWidth
                    divider.dragGrabOffset = value.startLocation.x - (leftPanelWidth + PanelDividerMetrics.hitAreaWidth / 2)
                    log.debug("[Divider] Drag begin")
                }

                let proposed = (value.location.x - divider.dragGrabOffset) - (PanelDividerMetrics.hitAreaWidth / 2)
                let maxW = containerWidth - PanelDividerMetrics.minPanelWidth - PanelDividerMetrics.hitAreaWidth
                let clamped = max(PanelDividerMetrics.minPanelWidth, min(proposed, maxW))
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
        let halfLeft = halfCenter - PanelDividerMetrics.hitAreaWidth / 2
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
        let centerX = snapped + PanelDividerMetrics.hitAreaWidth / 2
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

    @ViewBuilder
    private func inactiveGroove(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.ultraThinMaterial)
            .frame(width: 6, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .blur(radius: 0.5)
                    .offset(x: -0.5, y: -0.5)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.black.opacity(0.4), lineWidth: 1)
                    .blur(radius: 0.5)
                    .offset(x: 0.5, y: 0.5)
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(PanelDividerMetrics.Colors.grooveBorder, lineWidth: 0.5)
            )
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func activeDivider(height: CGFloat, lineWidth: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: lineWidth, height: height)
            .shadow(color: Color.black.opacity(0.35), radius: 5, x: 1, y: 0)
            .overlay(
                Rectangle()
                    .stroke(PanelDividerMetrics.Colors.grooveBorderActive, lineWidth: 0.5)
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Comparable Extension
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
