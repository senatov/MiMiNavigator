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
    let geometry: GeometryProxy
    @Binding var leftPanelWidth: CGFloat
    let fetchFiles: @MainActor (PanelSide) async -> Void
    @EnvironmentObject var appState: AppState

    @State private var tooltipText: String = ""
    @State private var tooltipPosition: CGPoint = .zero
    @State private var isDividerTooltipVisible: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            FilePanelView(
                currSide: .left,
                geometry: geometry,
                leftPanelWidth: $leftPanelWidth,
                fetchFiles: fetchFiles
            )
            .onAppear {
                appState.focusedSide = .left
            }
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
                currSide: .right,
                geometry: geometry,
                leftPanelWidth: $leftPanelWidth,
                fetchFiles: fetchFiles
            )
            .onAppear {
                appState.focusedSide = .right
            }

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
