    //
    //  PanelsRowView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 21.10.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import AppKit
import SwiftUI
    // MARK: - Main view containing two file panels and a draggable divider.
struct PanelsRowView: View {
    @EnvironmentObject var appState: AppState
    @Binding var leftPanelWidth: CGFloat
    @State private var tooltipText: String = ""
    @State private var tooltipPosition: CGPoint = .zero
    @State private var isDividerTooltipVisible: Bool = false
    let geometry: GeometryProxy
    let fetchFiles: @MainActor (PanelSide) async -> Void
    
        // MARK: -
    var body: some View {
        log.debug(#function + " with leftPanelWidth: \(leftPanelWidth)")
        return HStack(spacing: 0) {
            makeLeftPanel()
            makeDivider()
            makeRightPanel()
        }
        .overlay(
            makeTooltipOverlay()
        )
    }
    
        // MARK: - - Creates the left file panel view.
    private func makeLeftPanel() -> some View {
        log.debug(#function + " with leftPanelWidth: \(leftPanelWidth.rounded())")
        return FilePanelView(selectedSide: .left, geometry: geometry, leftPanelWidth: $leftPanelWidth, fetchFiles: fetchFiles, appState: appState)
    }
    
        /// Creates the right file panel view.
    private func makeRightPanel() -> some View {
        log.debug(#function + " with leftPanelWidth: \(leftPanelWidth.rounded())")
        return FilePanelView(selectedSide: .right, geometry: geometry, leftPanelWidth: $leftPanelWidth, fetchFiles: fetchFiles, appState: appState)
    }
    
        // MARK: - - Creates the divider view with drag handlers.
    private func makeDivider() -> some View {
        log.debug(#function + " with leftPanelWidth: \(leftPanelWidth.rounded())")
        return DividerView(
            geometry: geometry,
            leftPanelWidth: $leftPanelWidth,
            onDrag: { value in
                let newWidth = leftPanelWidth + value.translation.width
                let (tooltipText, tooltipPosition) = ToolTipMod.calculateTooltip(
                    location: value.location,
                    dividerX: newWidth,
                    totalWidth: geometry.size.width
                )
                self.tooltipText = tooltipText
                self.tooltipPosition = tooltipPosition
                self.isDividerTooltipVisible = true
            },
            onDragEnd: {
                self.isDividerTooltipVisible = false
            }
        )
    }
    
        // MARK: - - Creates the tooltip overlay view.
    private func makeTooltipOverlay() -> some View {
        log.debug(#function + " with isDividerTooltipVisible: \(isDividerTooltipVisible)")
        return Group {
            if isDividerTooltipVisible {
                PrettyTooltip(text: tooltipText)
                    .position(tooltipPosition)
                    .transition(.opacity)
                    .opacity(0.7)
                    .zIndex(1000)
            }
        }
    }
}
