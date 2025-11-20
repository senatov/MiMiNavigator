//  PanelsRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.10.2025.
//

import AppKit
import SwiftUI

// MARK: - PanelsRowView
struct PanelsRowView: View {
    @EnvironmentObject var appState: AppState
    // External
    @Binding var leftPanelWidth: CGFloat
    let geometry: GeometryProxy
    let fetchFiles: @MainActor (PanelSide) async -> Void
    // Tooltip state
    @State private var tooltipText: String = ""
    @State private var tooltipPosition: CGPoint = .zero
    @State private var isDividerTooltipVisible: Bool = false
    @State private var lastLoggedWidth: CGFloat = -1
    // Drag state
    @State private var dragStartWidth: CGFloat = .nan
    @State private var lastAppliedWidth: CGFloat = -1
    @State private var isDividerDragging: Bool = false
    // Tooltip throttle
    @State private var lastTooltipLeft: CGFloat = .nan
    @State private var dragGrabOffset: CGFloat = 0
    @State private var suppressDragUntilMouseUp: Bool = false
    private let dividerHitAreaWidth: CGFloat = 24
    // Do not relayout panels while dragging; draw a preview line instead
    @State private var dragPreviewLeft: CGFloat? = nil
    // Throttle UI logs for divider hover, cleaner output
    @State private var lastUILogTS: TimeInterval = 0

    // MARK: - Body
    var body: some View {
        if Int(leftPanelWidth.rounded()) != Int(lastLoggedWidth) {
            log.debug("PanelsRowView.body init with leftPanelWidth=\(leftPanelWidth.rounded())")
            let geomW = geometry.size.width
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            let halfCenter = (geomW / 2.0 * scale).rounded() / scale
            let halfLeft = halfCenter - dividerHitAreaWidth / 2
            log.debug(
                "DIV-INIT: geomW=\(Int(geomW)) scale=\(scale) halfCenter=\(Int(halfCenter)) halfLeft=\(Int(halfLeft)) currentLeft=\(Int(leftPanelWidth))"
            )
        }
        return ZStack(alignment: .center) {
            HStack(spacing: 0) {
                makeLeftPanel()
                makePanelHDivider()
                makeRightPanel()
            }
            .animation(nil, value: leftPanelWidth)
            .transaction { tx in
                if isDividerDragging {
                    tx.disablesAnimations = true
                    tx.animation = nil
                }
            }
            // Preview divider that does not trigger layout during drag
            if let previewX = dragPreviewLeft {
                Rectangle()
                    .fill(
                        isDividerDragging
                            ? Color(nsColor: .systemOrange) : Color(nsColor: NSColor.systemOrange.withAlphaComponent(0.55))
                    )
                    .frame(width: isDividerDragging ? 3.0 : 1.5, height: geometry.size.height)
                    .shadow(color: Color.black.opacity(isDividerDragging ? 0.16 : 0.0), radius: isDividerDragging ? 2 : 0, x: 0, y: 0)
                    .position(x: previewX, y: geometry.size.height / 2)
                    .allowsHitTesting(false)
            }
        }
        .modifier(
            ToolTipMod(
                isVisible: $isDividerTooltipVisible,
                text: tooltipText,
                position: tooltipPosition
            )
        )
        .onChange(of: leftPanelWidth) {
            let w = leftPanelWidth.rounded()
            if w != lastLoggedWidth {
                lastLoggedWidth = w
                log.debug("PanelsRowView.leftPanelWidth changed → \(w)")
            }
        }
    }

    // MARK: - Left Panels
    private func makeLeftPanel() -> some View {
        log.debug("makeLeftPanel() with leftPanelWidth=\(leftPanelWidth.rounded())")
        return FilePanelView(
            selectedSide: .left,
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles,
            appState: appState
        )
        .id("panel-left")
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = .left
            appState.forceFocusSelection()
            log.debug("PanelsRowView: focus -> .left via tap")
        }
        .zIndex(0)
        .animation(nil, value: leftPanelWidth)
    }

    // MARK: - Right Panels
    private func makeRightPanel() -> some View {
        log.debug("makeRightPanel() with leftPanelWidth=\(leftPanelWidth.rounded())")
        return FilePanelView(
            selectedSide: .right,
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles,
            appState: appState
        )
        .id("panel-right")
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = .right
            appState.forceFocusSelection()
            log.debug("PanelsRowView: focus -> .right via tap")
        }
        .zIndex(0)
        .animation(nil, value: leftPanelWidth)
    }

    // MARK: - Divider (macOS-like, custom color, smooth drag)
    private func makePanelHDivider() -> some View {
        // Visual states
        let normalColor = Color(nsColor: NSColor.systemOrange.withAlphaComponent(0.42))
        let activeColor = Color(nsColor: .systemOrange)
        let lineWidth: CGFloat = isDividerDragging ? 3.0 : 1.5
        let lineColor: Color = isDividerDragging ? activeColor : normalColor
        return ZStack {
            // Visible divider line
            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth, height: geometry.size.height)
                .shadow(color: Color.black.opacity(isDividerDragging ? 0.16 : 0.0), radius: isDividerDragging ? 2 : 0, x: 0, y: 0)
                .allowsHitTesting(false)
            // Invisible comfort grab zone
            Color.clear
                .frame(width: dividerHitAreaWidth, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            if suppressDragUntilMouseUp { return }
                            if !isDividerDragging { isDividerDragging = true }
                            if isDividerDragging && dragPreviewLeft == nil {
                                log.debug("Divider drag begin")
                                if dragPreviewLeft == nil {
                                    dragPreviewLeft = leftPanelWidth
                                    // Capture offset relative to divider CENTER, not left edge
                                    dragGrabOffset = value.startLocation.x - (leftPanelWidth + dividerHitAreaWidth / 2)
                                }
                            }
                            // Convert cursor position (near divider center) back to left panel width
                            let proposed = (value.location.x - dragGrabOffset) - (dividerHitAreaWidth / 2)
                            let minW: CGFloat = 80
                            // Reserve min for right panel and the divider itself
                            let maxW = geometry.size.width - minW - dividerHitAreaWidth
                            let clamped = max(minW, min(proposed, maxW))
                            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                            let snapped = (clamped * scale).rounded() / scale
                            if dragPreviewLeft == nil { dragPreviewLeft = leftPanelWidth }
                            let moved = abs((dragPreviewLeft ?? leftPanelWidth) - snapped) >= 0.5
                            if moved {
                                dragPreviewLeft = snapped
                                if Int(snapped) % 16 == 0 {
                                    let centerX = snapped + dividerHitAreaWidth / 2
                                    let percentLog = Int(((centerX / max(geometry.size.width, 1)) * 100.0).rounded())
                                    log.debug(
                                        "DIV-PREVIEW: proposed=\(Int(proposed)) clamped=\(Int(clamped)) snapped=\(Int(snapped)) centerX=\(Int(centerX)) percent=\(percentLog)% minW=80 maxW=\(Int(maxW))"
                                    )
                                }
                            }
                            let delta = abs((lastTooltipLeft.isNaN ? -9999 : lastTooltipLeft) - snapped)
                            if delta >= 2 {
                                lastTooltipLeft = snapped
                                // Percentage is based on divider CENTER position over the full width
                                let centerX = snapped + dividerHitAreaWidth / 2
                                let percent = Int(((centerX / max(geometry.size.width, 1)) * 100.0).rounded()).clamped(to: 0...100)
                                tooltipText = "\(percent)%"
                                tooltipPosition = CGPoint(
                                    x: centerX,
                                    y: max(34, value.location.y - 70)
                                )
                                isDividerTooltipVisible = true
                            }
                        }
                        .onEnded { _ in
                            suppressDragUntilMouseUp = false
                            var t = Transaction()
                            t.disablesAnimations = true
                            withTransaction(t) {
                                if let finalX = dragPreviewLeft {
                                    if leftPanelWidth != finalX { leftPanelWidth = finalX }
                                    DispatchQueue.main.async {
                                        if abs(leftPanelWidth - (finalX)) > 0.5 {
                                            log.debug("DIV-COMMIT: external override detected, re-asserting final width")
                                            leftPanelWidth = finalX
                                        }
                                    }
                                    lastAppliedWidth = finalX
                                }
                                dragGrabOffset = 0
                                dragStartWidth = .nan
                                isDividerTooltipVisible = false
                                isDividerDragging = false
                                lastTooltipLeft = .nan
                                dragPreviewLeft = nil
                            }
                            log.debug("Divider commit → leftPanelWidth=\(Int(leftPanelWidth)) totalW=\(Int(geometry.size.width))")
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            suppressDragUntilMouseUp = true
                            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                            // Center of divider at exact half; compute left width from it
                            let halfCenter = (geometry.size.width / 2.0 * scale).rounded() / scale
                            let halfLeft = halfCenter - dividerHitAreaWidth / 2
                            lastAppliedWidth = halfLeft
                            leftPanelWidth = halfLeft
                            DispatchQueue.main.async {
                                if abs(leftPanelWidth - halfLeft) > 0.5 {
                                    log.debug("DIV-DBL(simul): external override detected, re-asserting 50%")
                                    leftPanelWidth = halfLeft
                                }
                            }
                            tooltipText = "50%"
                            tooltipPosition = CGPoint(x: halfCenter, y: 46)
                            isDividerTooltipVisible = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                isDividerTooltipVisible = false
                            }
                            log.debug("Divider double-click (simul) → 50/50 center snap")
                        }
                )
                .simultaneousGesture(
                    TapGesture().modifiers(.option)
                        .onEnded {
                            suppressDragUntilMouseUp = true
                            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                            // Snap divider CENTER to exact half, then derive left panel width
                            let halfCenter = (geometry.size.width / 2.0 * scale).rounded() / scale
                            let halfLeft = halfCenter - dividerHitAreaWidth / 2
                            lastAppliedWidth = halfLeft
                            leftPanelWidth = halfLeft
                            DispatchQueue.main.async {
                                if abs(leftPanelWidth - halfLeft) > 0.5 {
                                    log.debug("DIV-OPT(simul-mod): external override detected, re-asserting 50%")
                                    leftPanelWidth = halfLeft
                                }
                            }
                            tooltipText = "50%"
                            tooltipPosition = CGPoint(x: halfCenter, y: 46)
                            isDividerTooltipVisible = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                isDividerTooltipVisible = false
                            }
                            log.debug("Divider option-tap (simul-mod) → 50/50 center snap")
                        }
                )
        }
        .frame(width: dividerHitAreaWidth, height: geometry.size.height)
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
        // Resize cursor via hover (SwiftUI .cursor may be unavailable on some targets)
        .onHover { inside in
            if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastUILogTS > 0.5 {
                lastUILogTS = now
                log.debug("Divider hover → inside=\(inside)")
            }
        }
        .allowsHitTesting(true)
        .zIndex(10)  // keep above rows but below bottom toolbar (Liquid Glass design)
    }
}

// MARK: -
extension Comparable {
    /// Clamp value to a closed range.
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
