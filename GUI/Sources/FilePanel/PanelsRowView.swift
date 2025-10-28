//
//  PanelsRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.10.2025.
//  Updated on 26.10.2025
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

    // MARK: - Body
    var body: some View {
        // Log creation (useful to detect excessive re-renders)
        log.debug("PanelsRowView.body init with leftPanelWidth=\(leftPanelWidth.rounded())")

        // Use ZStack to ensure tooltip does not affect layout/height of panels
        return ZStack(alignment: .center) {
            HStack(spacing: 0) {
                makeLeftPanel()
                makeDivider()
                makeRightPanel()
            }
            // Tooltip is rendered as sibling overlay (non-intrusive to layout)
            makeTooltipOverlay()
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
    }

    // MARK: - Divider
    private func makeDivider() -> some View {
        log.debug("makeDivider() with leftPanelWidth=\(leftPanelWidth.rounded())")
        return DividerView(
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            onDrag: { value in
                // Update live width during drag
                let newWidth = leftPanelWidth + value.translation.width
                let clamped = max(0, min(newWidth, geometry.size.width))
                leftPanelWidth = clamped

                // Calculate tooltip content and position (helper)
                let (text, pos) = ToolTipMod.calculateTooltip(
                    location: value.location,
                    dividerX: leftPanelWidth,
                    totalWidth: geometry.size.width
                )
                self.tooltipText = text
                self.tooltipPosition = pos
                self.isDividerTooltipVisible = true

                // Log drag diagnostics
                log.debug(
                    "Divider drag → loc=(\(Int(value.location.x));\(Int(value.location.y))) lpw=\(Int(leftPanelWidth))/\(Int(geometry.size.width))"
                )
            },
            onDragEnd: {
                // Hide tooltip when user finishes dragging
                self.isDividerTooltipVisible = false
                log.debug("Divider drag end → leftPanelWidth=\(Int(leftPanelWidth)) totalW=\(Int(geometry.size.width))")
            }
        )
        .allowsHitTesting(true)
    }

    // MARK: - Tooltip overlay (non-intrusive to layout)
    private func makeTooltipOverlay() -> some View {
        log.debug("makeTooltipOverlay() visible=\(isDividerTooltipVisible)")
        return Group {
            if isDividerTooltipVisible {
                PrettyTooltip(text: tooltipText)
                    .position(tooltipPosition)
                    .transition(.opacity)
                    .opacity(0.85)
                    .zIndex(1000)
                    .allowsHitTesting(false)  // do not block mouse events behind the tooltip
            }
        }
    }
}
