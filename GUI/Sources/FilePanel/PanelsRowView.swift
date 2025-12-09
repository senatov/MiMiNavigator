// PanelsRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.10.2025.
//

import AppKit
import SwiftUI

// MARK: - Divider drag state (grouped)
private struct DividerState {
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

// MARK: - Divider appearance constants
private enum DividerStyle {
    static let hitAreaWidth: CGFloat = 24
    static let normalWidth: CGFloat = 1.2
    static let activeWidth: CGFloat = 4.0
    static let normalColor = Color(nsColor: NSColor.separatorColor)
    static let activeColor = Color.red
    static let minPanelWidth: CGFloat = 80
}

// MARK: - PanelsRowView
struct PanelsRowView: View {
    @Environment(AppState.self) var appState
    @Binding var leftPanelWidth: CGFloat
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let fetchFiles: @MainActor (PanelSide) async -> Void
    
    @State private var divider = DividerState()

    // MARK: - Body
    var body: some View {
        logWidthChangeIfNeeded()
        
        return ZStack(alignment: .center) {
            HStack(spacing: 0) {
                makeLeftPanel()
                makePanelDivider()
                makeRightPanel()
            }
            .animation(nil, value: leftPanelWidth)
            .transaction { tx in
                if divider.isDragging {
                    tx.disablesAnimations = true
                    tx.animation = nil
                }
            }
            
            // Preview divider (doesn't trigger layout during drag)
            if let previewX = divider.dragPreviewLeft {
                Rectangle()
                    .fill(DividerStyle.activeColor)
                    .frame(width: DividerStyle.activeWidth, height: containerHeight)
                    .position(x: previewX, y: containerHeight / 2)
                    .allowsHitTesting(false)
            }
        }
        .modifier(
            ToolTipMod(
                isVisible: $divider.isTooltipVisible,
                text: divider.tooltipText,
                position: divider.tooltipPosition
            )
        )
        .onChange(of: leftPanelWidth) {
            let w = leftPanelWidth.rounded()
            if w != divider.lastLoggedWidth {
                divider.lastLoggedWidth = w
                log.debug("PanelsRowView.leftPanelWidth changed → \(w)")
            }
        }
    }
    
    // MARK: - Width change logging (throttled)
    private func logWidthChangeIfNeeded() {
        if Int(leftPanelWidth.rounded()) != Int(divider.lastLoggedWidth) {
            log.debug("PanelsRowView.body init with leftPanelWidth=\(leftPanelWidth.rounded())")
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            let halfCenter = (containerWidth / 2.0 * scale).rounded() / scale
            let halfLeft = halfCenter - DividerStyle.hitAreaWidth / 2
            log.debug(
                "DIV-INIT: containerW=\(Int(containerWidth)) scale=\(scale) halfCenter=\(Int(halfCenter)) halfLeft=\(Int(halfLeft)) currentLeft=\(Int(leftPanelWidth))"
            )
        }
    }

    // MARK: - Left Panel
    private func makeLeftPanel() -> some View {
        FilePanelView(
            selectedSide: .left,
            containerWidth: containerWidth,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles,
            appState: appState
        )
        .id("panel-left")
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = .left
            log.debug("PanelsRowView: focus -> .left via tap")
        }
        .zIndex(0)
        .animation(nil, value: leftPanelWidth)
    }

    // MARK: - Right Panel
    private func makeRightPanel() -> some View {
        FilePanelView(
            selectedSide: .right,
            containerWidth: containerWidth,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles,
            appState: appState
        )
        .id("panel-right")
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = .right
            log.debug("PanelsRowView: focus -> .right via tap")
        }
        .zIndex(0)
        .animation(nil, value: leftPanelWidth)
    }

    // MARK: - Panel Divider
    private func makePanelDivider() -> some View {
        let lineWidth = divider.isDragging ? DividerStyle.activeWidth : DividerStyle.normalWidth
        let lineColor = divider.isDragging ? DividerStyle.activeColor : DividerStyle.normalColor
        
        return ZStack {
            // Visible divider line
            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth, height: containerHeight)
                .shadow(
                    color: Color.black.opacity(divider.isDragging ? 0.16 : 0.0),
                    radius: divider.isDragging ? 2 : 0
                )
                .allowsHitTesting(false)
            
            // Invisible hit area for comfortable grabbing
            Color.clear
                .frame(width: DividerStyle.hitAreaWidth, height: containerHeight)
                .contentShape(Rectangle())
                .gesture(makeDragGesture())
                .simultaneousGesture(makeDoubleTapGesture())
                .simultaneousGesture(makeOptionTapGesture())
        }
        .frame(width: DividerStyle.hitAreaWidth, height: containerHeight)
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
            #if DEBUG
            let now = ProcessInfo.processInfo.systemUptime
            if now - divider.lastUILogTS > 0.5 {
                divider.lastUILogTS = now
                log.debug("Divider hover → inside=\(inside)")
            }
            #endif
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
                    divider.dragGrabOffset = value.startLocation.x - (leftPanelWidth + DividerStyle.hitAreaWidth / 2)
                    log.debug("Divider drag begin")
                }
                
                let proposed = (value.location.x - divider.dragGrabOffset) - (DividerStyle.hitAreaWidth / 2)
                let maxW = containerWidth - DividerStyle.minPanelWidth - DividerStyle.hitAreaWidth
                let clamped = max(DividerStyle.minPanelWidth, min(proposed, maxW))
                let snapped = snapToPixelGrid(clamped)
                
                let moved = abs((divider.dragPreviewLeft ?? leftPanelWidth) - snapped) >= 0.5
                if moved {
                    divider.dragPreviewLeft = snapped
                    #if DEBUG
                    if Int(snapped) % 16 == 0 {
                        let centerX = snapped + DividerStyle.hitAreaWidth / 2
                        let percentLog = Int(((centerX / max(containerWidth, 1)) * 100.0).rounded())
                        log.debug("DIV-PREVIEW: snapped=\(Int(snapped)) percent=\(percentLog)%")
                    }
                    #endif
                }
                
                updateTooltip(snapped: snapped, locationY: value.location.y)
            }
            .onEnded { _ in
                commitDrag()
            }
    }
    
    // MARK: - Double Tap Gesture (50/50 reset)
    private func makeDoubleTapGesture() -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                snapToCenter()
                log.debug("Divider double-click → 50/50 center snap")
            }
    }
    
    // MARK: - Option+Tap Gesture (50/50 reset)
    private func makeOptionTapGesture() -> some Gesture {
        TapGesture().modifiers(.option)
            .onEnded {
                snapToCenter()
                log.debug("Divider option-tap → 50/50 center snap")
            }
    }
    
    // MARK: - Snap to 50/50 center
    private func snapToCenter() {
        divider.suppressDragUntilMouseUp = true
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let halfCenter = (containerWidth / 2.0 * scale).rounded() / scale
        let halfLeft = halfCenter - DividerStyle.hitAreaWidth / 2
        
        divider.lastAppliedWidth = halfLeft
        leftPanelWidth = halfLeft
        
        Task { @MainActor in
            if abs(leftPanelWidth - halfLeft) > 0.5 {
                leftPanelWidth = halfLeft
            }
        }
        
        showTooltip(text: "50%", at: CGPoint(x: halfCenter, y: 46))
        
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            divider.isTooltipVisible = false
        }
    }
    
    // MARK: - Commit drag changes
    private func commitDrag() {
        divider.suppressDragUntilMouseUp = false
        
        var transaction = Transaction()
        transaction.disablesAnimations = true
        
        withTransaction(transaction) {
            if let finalX = divider.dragPreviewLeft {
                if leftPanelWidth != finalX {
                    leftPanelWidth = finalX
                }
                Task { @MainActor in
                    if abs(leftPanelWidth - finalX) > 0.5 {
                        leftPanelWidth = finalX
                    }
                }
                divider.lastAppliedWidth = finalX
            }
            
            // Reset state
            divider.dragGrabOffset = 0
            divider.dragStartWidth = .nan
            divider.isTooltipVisible = false
            divider.isDragging = false
            divider.lastTooltipLeft = .nan
            divider.dragPreviewLeft = nil
        }
        
        log.debug("Divider commit → leftPanelWidth=\(Int(leftPanelWidth)) totalW=\(Int(containerWidth))")
    }
    
    // MARK: - Update tooltip during drag
    private func updateTooltip(snapped: CGFloat, locationY: CGFloat) {
        let delta = abs((divider.lastTooltipLeft.isNaN ? -9999 : divider.lastTooltipLeft) - snapped)
        guard delta >= 2 else { return }
        
        divider.lastTooltipLeft = snapped
        let centerX = snapped + DividerStyle.hitAreaWidth / 2
        let percent = Int(((centerX / max(containerWidth, 1)) * 100.0).rounded()).clamped(to: 0...100)
        
        showTooltip(
            text: "\(percent)%",
            at: CGPoint(x: centerX, y: max(34, locationY - 70))
        )
    }
    
    // MARK: - Show tooltip
    private func showTooltip(text: String, at position: CGPoint) {
        divider.tooltipText = text
        divider.tooltipPosition = position
        divider.isTooltipVisible = true
    }
    
    // MARK: - Snap to pixel grid
    private func snapToPixelGrid(_ value: CGFloat) -> CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return (value * scale).rounded() / scale
    }
}

// MARK: - Comparable extension
extension Comparable {
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
