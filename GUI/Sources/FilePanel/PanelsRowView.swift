    //
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
        // Diagnostics
    @State private var containerSize: CGSize = .zero
    @State private var lastLoggedWidth: CGFloat = -1
        // Drag state
    @State private var dragStartWidth: CGFloat = .nan
    @State private var lastAppliedWidth: CGFloat = -1
    @State private var isDividerDragging: Bool = false
        // Tooltip throttle
    @State private var lastTooltipLeft: CGFloat = .nan
    
        // Do not relayout panels while dragging; draw a preview line instead
    @State private var dragPreviewLeft: CGFloat? = nil
        // Throttle timestamp for size-change logs
    @State private var lastSizeLogTS: TimeInterval = 0
        // Throttle UI logs for divider hover, cleaner output
    @State private var lastUILogTS: TimeInterval = 0
    
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
            .transaction { tx in
                if isDividerDragging {
                    tx.disablesAnimations = true
                    tx.animation = nil
                }
            }
            
                // Preview divider that does not trigger layout during drag
            if let previewX = dragPreviewLeft {
                Rectangle()
                    .fill(isDividerDragging ? Color(nsColor: .systemOrange) : Color(nsColor: NSColor.systemOrange.withAlphaComponent(0.55)))
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
                            // Throttle size logs to avoid noise during incidental updates
                        let now = ProcessInfo.processInfo.systemUptime
                        if now - lastSizeLogTS >= 0.30 {
                            lastSizeLogTS = now
                            log.debug("PanelsRowView.size changed → \(Int(gp.size.width))x\(Int(gp.size.height))")
                        }
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
    
        // MARK: - Left & Right Panels
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
    
        // MARK: - Divider (macOS-like, custom color, smooth drag)
    private func makeDivider() -> some View {
            // Visual states
        let normalColor = Color(nsColor: NSColor.systemOrange.withAlphaComponent(0.42))
        let activeColor = Color(nsColor: .systemOrange)
        let hitAreaWidth: CGFloat = 24
        let lineWidth: CGFloat = isDividerDragging ? 3.0 : 1.5
        let lineColor: Color = isDividerDragging ? activeColor : normalColor
        return ZStack {
                // Visible divider line
            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth)
                .shadow(color: Color.black.opacity(isDividerDragging ? 0.16 : 0.0), radius: isDividerDragging ? 2 : 0, x: 0, y: 0)
                // Invisible comfort grab zone
            Color.clear
                .frame(width: hitAreaWidth)
        }
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
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                        // Begin drag
                    if !isDividerDragging { isDividerDragging = true }
                    if dragStartWidth.isNaN { dragStartWidth = leftPanelWidth }
                        // Compute proposed width
                    let proposed = dragStartWidth + value.translation.width
                        // Respect min widths for both panels
                    let minW: CGFloat = 80
                    let maxW = geometry.size.width - minW
                    let clamped = max(minW, min(proposed, maxW))
                        // Pixel snap to device scale
                    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                    let snapped = (clamped * scale).rounded() / scale
                        // Do not relayout panels while dragging; preview only
                    if dragPreviewLeft == nil { dragPreviewLeft = leftPanelWidth }
                    let moved = abs((dragPreviewLeft ?? leftPanelWidth) - snapped) >= 0.5
                    if moved {
                        dragPreviewLeft = snapped
                        if Int(snapped) % 16 == 0 {
                            log.debug("Divider preview → x=\(Int(snapped)) / total=\(Int(geometry.size.width))")
                        }
                    }
                        // Throttle tooltip updates to avoid layout jitter (~2pt steps)
                    let delta = abs((lastTooltipLeft.isNaN ? -9999 : lastTooltipLeft) - snapped)
                    if delta >= 2 {
                        lastTooltipLeft = snapped
                        let percent = Int((snapped / max(geometry.size.width, 1)) * 100).clamped(to: 0...100)
                        tooltipText = "\(percent)%"
                        tooltipPosition = CGPoint(
                            x: snapped + 120,
                            y: max(34, value.location.y - 70)  // slightly below previous for better readability
                        )
                        isDividerTooltipVisible = true
                    }
                }
                .onEnded { _ in
                        // Commit final width once, clear preview and flags
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) {
                        if let finalX = dragPreviewLeft {
                            leftPanelWidth = finalX
                            lastAppliedWidth = finalX
                        }
                        dragStartWidth = .nan
                        isDividerTooltipVisible = false
                        isDividerDragging = false
                        lastTooltipLeft = .nan
                        dragPreviewLeft = nil
                    }
                    log.debug("Divider commit → leftPanelWidth=\(Int(leftPanelWidth)) totalW=\(Int(geometry.size.width))")
                }
        )
            // Double-click: reset to 50/50 and show quick tooltip
        .onTapGesture(count: 2) {
            let half = geometry.size.width / 2
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                leftPanelWidth = half
            }
            tooltipText = "50%"
            tooltipPosition = CGPoint(x: half + 120, y: 46)
            isDividerTooltipVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isDividerTooltipVisible = false
            }
            log.debug("Divider double-click → 50/50")
        }
        .allowsHitTesting(true)
    }
}

extension Comparable {
        /// Clamp value to a closed range.
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
