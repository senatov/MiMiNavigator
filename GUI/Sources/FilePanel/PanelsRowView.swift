// PanelsRowView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 21.10.2025.
// Refactored: 12.02.2026 — extracted PanelDividerView
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Horizontal layout of left panel + divider + right panel

import SwiftUI

// MARK: - PanelsRowView
/// Arranges two FilePanelViews side by side with a draggable divider between them.
/// Delegates all divider logic to PanelDividerView.
struct PanelsRowView: View {
    @Environment(AppState.self) var appState
    @Binding var leftPanelWidth: CGFloat
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let fetchFiles: @MainActor (PanelSide) async -> Void

    @State private var divider = DividerDragState()

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                makeLeftPanel()
                PanelDividerView(
                    leftPanelWidth: $leftPanelWidth,
                    divider: $divider,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight
                )
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
                    .fill(PanelDividerStyle.activeColor)
                    .frame(width: PanelDividerStyle.activeWidth, height: containerHeight)
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
            log.debug("[PanelsRow] Focus → left")
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
            log.debug("[PanelsRow] Focus → right")
        }
        .zIndex(0)
        .animation(nil, value: leftPanelWidth)
    }
}
