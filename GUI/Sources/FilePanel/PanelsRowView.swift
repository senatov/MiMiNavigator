    //
    //  PanelsRowView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 21.10.2025.
    //  Updated on 26.10.2025
    //

import AppKit
import SwiftUI

    // Lightweight clamp helper for percentages and other comparables
private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}


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
    
        // Lightweight drag state for divider (no heavy computations)
    @State private var dragStartWidth: CGFloat = .nan
    @State private var lastAppliedWidth: CGFloat = -1
    
        // Drag lifecycle flag to suppress animations while resizing
    @State private var isDividerDragging: Bool = false
    
        // MARK: - Body
    var body: some View {
            // Log creation (useful to detect excessive re-renders)
        if Int(leftPanelWidth.rounded()) != Int(lastLoggedWidth) {
            log.debug("PanelsRowView.body init with leftPanelWidth=\(leftPanelWidth.rounded())")
        }
        
            // Use ZStack to ensure tooltip does not affect layout/height of panels
        return ZStack(alignment: .center) {
            HStack(spacing: 0) {
                makeLeftPanel()
                makeDivider()
                makeRightPanel()
            }
            .animation(nil, value: leftPanelWidth)
            makeTooltipOverlay() // render bubble above panels without affecting layout
        }
            // Suppress implicit animations during divider dragging to avoid jitter
        .transaction { tx in
            if isDividerDragging {
                tx.disablesAnimations = true
                tx.animation = nil
            }
        }
            // Occupy all available space (no top alignment!)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
            // Lightweight size reporting for diagnostics (no layout mutation)
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
            // Log width changes coming from divider drag (to detect jitter)
        .onChange(of: leftPanelWidth) {
            let w = leftPanelWidth.rounded()
                // Avoid flooding logs with identical values
            if w != lastLoggedWidth {
                lastLoggedWidth = w
                log.debug("PanelsRowView.leftPanelWidth changed → \(w)")
            }
        }
    }
    
        // MARK: - Left panel
    private func makeLeftPanel() -> some View {
            // Note: FilePanelView should internally size to provided geometry width.
        log.debug("makeLeftPanel() with leftPanelWidth=\(leftPanelWidth.rounded())")
        return FilePanelView(
            selectedSide: .left,
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles,
            appState: appState
        )
            // If you need to force width strictly, uncomment:
            // .frame(width: leftPanelWidth)
            // But usually FilePanelView handles its width using GeometryProxy + leftPanelWidth.
        .id("panel-left")
        .contentShape(Rectangle())  // ensure taps on empty space count
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                        // Explicitly focus left panel
                    appState.focusedPanel = .left
                    appState.forceFocusSelection()
                    log.debug("PanelsRowView: focus -> .left via tap")
                }
        )
        .animation(nil, value: leftPanelWidth) // prevent implicit width animations causing jitter
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
            // Same note as left panel about explicit width if needed.
        .id("panel-right")
        .contentShape(Rectangle())  // ensure taps on empty space count
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                        // Explicitly focus right panel
                    appState.focusedPanel = .right
                    appState.forceFocusSelection()
                    log.debug("PanelsRowView: focus -> .right via tap")
                }
        )
        .animation(nil, value: leftPanelWidth) // prevent implicit width animations causing jitter
    }
    
        // MARK: - Divider (lightweight, DragGesture-only)
    private func makeDivider() -> some View {
            // Visual separator + wide hit area to make dragging easy without heavy overlays
        let visualLine: Color = isDividerDragging ? Color.orange : Color.gray.opacity(0.45)
        let hitColor = Color.clear
        
        return ZStack {
                // Visible hairline for the divider
            visualLine.frame(width: 1)
            
                // Wider invisible hit area purely for interaction
            hitColor.frame(width: 8)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                        // Mark drag started to suppress animations globally
                    if !isDividerDragging { isDividerDragging = true }
                    
                        // Initialize drag start lazily to avoid layout feedback
                    if dragStartWidth.isNaN { dragStartWidth = leftPanelWidth }
                    
                        // Compute clamped width and snap to device pixels to avoid subpixel jitter
                    let proposed = dragStartWidth + value.translation.width
                    let clamped = max(0, min(proposed, geometry.size.width))
                    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                    let snapped = (clamped * scale).rounded() / scale
                    
                        // Apply without animation to prevent panel shaking
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        if abs(snapped - leftPanelWidth) >= 1.0 {
                            leftPanelWidth = snapped
                            lastAppliedWidth = snapped
                            log.debug("Divider drag width → \(Int(snapped))/\(Int(geometry.size.width))")
                        }
                    }
                    
                        // Update tooltip at the top-right of the divider/cursor
                    let percent = Int((snapped / max(geometry.size.width, 1)) * 100).clamped(to: 0...100)
                    tooltipText = "\(percent)%"
                        // Place slightly to the right and above the divider to avoid cursor overlap
                    tooltipPosition = CGPoint(x: snapped + 52, y: max(34, value.location.y - 42))
                    isDividerTooltipVisible = true
                }
                .onEnded { _ in
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        dragStartWidth = .nan
                        isDividerTooltipVisible = false
                        isDividerDragging = false
                    }
                    log.debug("Divider drag end → leftPanelWidth=\(Int(leftPanelWidth)) totalW=\(Int(geometry.size.width))")
                }
        )
            // Ensure divider does not steal clicks except for drag itself
        .allowsHitTesting(true)
    }
    
        // MARK: - Tooltip overlay (comic-style speech bubble)
    private func makeTooltipOverlay() -> some View {
        Group {
            if isDividerTooltipVisible {
                SpeechBubble(tailSize: CGSize(width: 14, height: 10),
                             cornerRadius: 14,
                             tailOffset: .init(x: -10, y: 12))
                .fill(Color.yellow.opacity(0.14)) // pale yellow
                .overlay(
                    SpeechBubble(tailSize: CGSize(width: 14, height: 10),
                                 cornerRadius: 14,
                                 tailOffset: .init(x: -10, y: 12))
                    .stroke(Color.primary.opacity(0.18), lineWidth: 0.8)
                )
                .frame(width: 120, height: 60) // ~3x bigger than before
                .overlay(
                    Text(tooltipText)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color(.sRGB, red: 0.08, green: 0.18, blue: 0.45, opacity: 1.0))
                )
                .shadow(radius: 10, x: 0, y: 3)
                .position(tooltipPosition)
                .transition(.opacity)
                .opacity(0.98)
                .zIndex(1000)
                .allowsHitTesting(false)
            }
        }
    }
}


    // MARK: - Comic speech bubble shape
struct SpeechBubble: Shape {
    var tailSize: CGSize
    var cornerRadius: CGFloat
    var tailOffset: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
            // Main rounded rect
        let bubbleRect = rect.insetBy(dx: 1, dy: 1)
        let r = min(cornerRadius, min(bubbleRect.width, bubbleRect.height) / 2)
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: r, height: r))
        
            // Tail near bottom-left corner, pointing toward the divider
        let tailBaseX = bubbleRect.minX + max(6, 12 + tailOffset.x)
        let tailBaseY = bubbleRect.maxY - max(6, 10 + tailOffset.y)
        let tailTip = CGPoint(x: tailBaseX - tailSize.width, y: tailBaseY + tailSize.height * 0.2)
        let baseLeft = CGPoint(x: tailBaseX + tailSize.width * 0.2, y: tailBaseY - tailSize.height * 0.2)
        let baseRight = CGPoint(x: tailBaseX + tailSize.width * 0.8, y: tailBaseY + tailSize.height * 0.6)
        
        path.move(to: baseLeft)
        path.addLine(to: tailTip)
        path.addLine(to: baseRight)
        path.closeSubpath()
        return path
    }
}
