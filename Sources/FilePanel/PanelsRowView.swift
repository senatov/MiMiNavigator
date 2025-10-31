    //
    //  PanelsRowView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 21.10.2025.
    //

import AppKit
import SwiftUI

    // MARK: - Main view containing two file panels and a draggable divider.
struct PanelsRowView: View {
    @EnvironmentObject var appState: AppState
        // External state
    @Binding var leftPanelWidth: CGFloat
    let geometry: GeometryProxy
    let fetchFiles: @MainActor (PanelSide) async -> Void
        // Tooltip state for divider drag
    @State private var tooltipText: String = ""
    @State private var tooltipPosition: CGPoint = .zero
    @State private var isDividerTooltipVisible: Bool = false
        // Local diagnostics
    @State private var containerSize: CGSize = .zero
    @State private var lastLoggedWidth: CGFloat = -1
        // Throttle tooltip updates to avoid jitter
    @State private var lastTooltipLeft: CGFloat = .nan
    
        // Lightweight drag state for divider
    @State private var dragStartWidth: CGFloat = .nan
    @State private var lastAppliedWidth: CGFloat = -1
    
        // Drag lifecycle flag to suppress animations while resizing
    @State private var isDividerDragging: Bool = false
    
        // MARK: - Body
    var body: some View {
        if Int(leftPanelWidth.rounded()) != Int(lastLoggedWidth) {
            log.debug("PanelsRowView.body init with leftPanelWidth=\(leftPanelWidth.rounded())")
        }
        return ZStack(alignment: .center) {
            HStack(spacing: 0) {
                makeLeftPanel()
                makeDivider()
                makeRightPanel()
            }
            .animation(nil, value: leftPanelWidth)
            makeTooltipOverlay()
        }
        .transaction { tx in
            if isDividerDragging {
                tx.disablesAnimations = true
                tx.animation = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
        .background(
            GeometryReader { gp in
                Color.clear
                    .onAppear {
                        containerSize = gp.size
                        log.debug("PanelsRowView.size onAppear → \(Int(gp.size.width))x\(Int(gp.size.height))")
                    }
                    .onChange(of: gp.size) {
                        containerSize = gp.size
                        log.debug("PanelsRowView.size changed → \(Int(gp.size.width))x\(Int(gp.size.height))")
                    }
                    .onDisappear { log.debug("PanelsRowView.size onDisappear") }
            }
        )
        .onChange(of: leftPanelWidth) {
            let w = leftPanelWidth.rounded()
            if w != lastLoggedWidth {
                lastLoggedWidth = w
                log.debug("PanelsRowView.leftPanelWidth changed → \(w)")
            }
        }
    }
    
        // MARK: - Left panel
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
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    appState.focusedPanel = .left
                    appState.forceFocusSelection()
                    log.debug("PanelsRowView: focus -> .left via tap")
                }
        )
        .animation(nil, value: leftPanelWidth)
    }
    
        // MARK: - Right panel
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
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    appState.focusedPanel = .right
                    appState.forceFocusSelection()
                    log.debug("PanelsRowView: focus -> .right via tap")
                }
        )
        .animation(nil, value: leftPanelWidth)
    }
    
        // MARK: - Divider (macOS-style, with tooltip)
    private func makeDivider() -> some View {
        let normalColor = Color(nsColor: NSColor.systemOrange.withAlphaComponent(0.55))
        let activeColor = Color(nsColor: .systemOrange)
        let hitColor = Color.clear
        
        let lineWidth: CGFloat = isDividerDragging ? 3.0 : 1.5
        let lineColor: Color = isDividerDragging ? activeColor : normalColor
        
        return ZStack {
            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth)
            hitColor.frame(width: 24)
        }
        .contentShape(Rectangle())
        .onHover { inside in
                // Set appropriate cursor when hovering over the divider
            if inside {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDividerDragging { isDividerDragging = true }
                    if dragStartWidth.isNaN { dragStartWidth = leftPanelWidth }
                    
                    let proposed = dragStartWidth + value.translation.width
                    let minW: CGFloat = 80
                    let clamped = max(minW, min(proposed, geometry.size.width - minW))
                    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                    let snapped = (clamped * scale).rounded() / scale
                    
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        if abs(snapped - leftPanelWidth) >= 0.5 {  // smoother tracking, avoid subpixel churn
                            leftPanelWidth = snapped
                            lastAppliedWidth = snapped
                            if Int(snapped) % 8 == 0 {  // log less often to reduce IO pauses
                                log.debug("Divider drag width → \(Int(snapped))/\(Int(geometry.size.width))")
                            }
                        }
                    }
                    
                        // Throttle tooltip updates to reduce layout churn
                    let delta = abs((lastTooltipLeft.isNaN ? -9999 : lastTooltipLeft) - snapped)
                    if delta >= 2 {  // update every ~2pt only
                        lastTooltipLeft = snapped
                        let percent = Int((snapped / max(geometry.size.width, 1)) * 100).clamped(to: 0...100)
                        tooltipText = "\(percent)%"
                        tooltipPosition = CGPoint(x: snapped + 120, y: max(34, value.location.y - 90))
                        isDividerTooltipVisible = true
                    }
                }
                .onEnded { _ in
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        dragStartWidth = .nan
                        isDividerTooltipVisible = false
                        isDividerDragging = false
                        lastTooltipLeft = .nan
                    }
                    log.debug("Divider drag end → leftPanelWidth=\(Int(leftPanelWidth)) totalW=\(Int(geometry.size.width))")
                }
        )
        .onTapGesture(count: 2) {
            let half = geometry.size.width / 2
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                leftPanelWidth = half
            }
            tooltipText = "50%"
            tooltipPosition = CGPoint(x: half + 120, y: 34)
            isDividerTooltipVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isDividerTooltipVisible = false
            }
            log.debug("Divider double-click → 50/50")
        }
        .allowsHitTesting(true)
    }
    
        // MARK: - Tooltip overlay
    private func makeTooltipOverlay() -> some View {
        Group {
            if isDividerTooltipVisible {
                SpeechBubble(
                    tailSize: CGSize(width: 14, height: 10),
                    cornerRadius: 14,
                    tailOffset: .init(x: -10, y: 12)
                )
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    SpeechBubble(
                        tailSize: CGSize(width: 14, height: 10),
                        cornerRadius: 14,
                        tailOffset: .init(x: -10, y: 12)
                    )
                    .stroke(Color.primary.opacity(0.25), lineWidth: 0.8)
                )
                .frame(width: 120, height: 60)
                .overlay(
                    Text(tooltipText)
                        .font(.system(size: 19, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color(.sRGB, red: 0.08, green: 0.18, blue: 0.45, opacity: 1.0))
                )
                .shadow(radius: 10, x: 0, y: 3)
                .position(tooltipPosition)
                .transition(.opacity)
                .zIndex(1000)
                .allowsHitTesting(false)
            }
        }
    }
}

    // Lightweight clamp helper for percentages and other comparables
extension Comparable {
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
