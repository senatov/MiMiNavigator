    //
    //  PanelsRowView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 21.10.2025.
    //  Updated by ChatGPT on 26.10.2025
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
    
        // MARK: - Body
    var body: some View {
        log.debug(#function + " with leftPanelWidth: \(leftPanelWidth)")
        return HStack(spacing: 0) {
            makeLeftPanel()
            makeDivider()
            makeRightPanel()
        }
            // Overlay that shows helper tooltip during divider drag
        .overlay(
            makeTooltipOverlay()
        )
            // Fill the available space between top bar and bottom toolbar
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .layoutPriority(1)
    }
    
        // MARK: - Creates the left file panel view.
    private func makeLeftPanel() -> some View {
        log.debug(#function + " with leftPanelWidth: \(leftPanelWidth.rounded())")
        return FilePanelView(
            selectedSide: .left,
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles,
            appState: appState
        )
    }
    
        // MARK: - Creates the right file panel view.
    private func makeRightPanel() -> some View {
        log.debug(#function + " with leftPanelWidth: \(leftPanelWidth.rounded())")
        return FilePanelView(
            selectedSide: .right,
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            fetchFiles: fetchFiles,
            appState: appState
        )
    }
    
        // MARK: - Creates the divider view with drag handlers.
    private func makeDivider() -> some View {
        log.debug(#function + " with leftPanelWidth: \(leftPanelWidth.rounded())")
        return DividerView(
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            onDrag: { value in
                    // Update live width during drag
                let newWidth = leftPanelWidth + value.translation.width
                leftPanelWidth = max(0, min(newWidth, geometry.size.width))
                
                    // Calculate tooltip content and position (helper)
                let (text, pos) = ToolTipMod.calculateTooltip(
                    location: value.location,
                    dividerX: leftPanelWidth,
                    totalWidth: geometry.size.width
                )
                self.tooltipText = text
                self.tooltipPosition = pos
                self.isDividerTooltipVisible = true
            },
            onDragEnd: {
                    // Hide tooltip when user finishes dragging
                self.isDividerTooltipVisible = false
            }
        )
    }
    
        // MARK: - Creates the tooltip overlay view.
    private func makeTooltipOverlay() -> some View {
        log.debug(#function + " with isDividerTooltipVisible: \(isDividerTooltipVisible)")
        return Group {
            if isDividerTooltipVisible {
                PrettyTooltip(text: tooltipText)
                    .position(tooltipPosition)
                    .transition(.opacity)
                    .opacity(0.8)
                    .zIndex(1000)
                    .allowsHitTesting(false) // do not block mouse events behind the tooltip
            }
        }
    }
}
