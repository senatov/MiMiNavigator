//
//  PanelsRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

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
        HStack(spacing: 0) {
            FilePanelView(selectedSide: .left, geometry: geometry, leftPanelWidth: $leftPanelWidth,
                          fetchFiles: fetchFiles, appState: appState)
            DividerView(
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
            FilePanelView(
                selectedSide: .right,
                geometry: geometry,
                leftPanelWidth: $leftPanelWidth, // We calculate the right part based on the total size and the left part.
                fetchFiles: fetchFiles,
                appState: appState
            )
        }
        .overlay(
            Group {
                if isDividerTooltipVisible {
                    PrettyTooltip(text: tooltipText)
                        .position(tooltipPosition)
                        .transition(.opacity)
                        .opacity(0.7)
                        .zIndex(1000)
                }
            }
        )
    }
}
