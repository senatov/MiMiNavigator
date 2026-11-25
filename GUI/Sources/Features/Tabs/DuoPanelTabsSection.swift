// DuoPanelTabsSection.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Detached bottom tab strip aligned with the dual file panels.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Duo Panel Tabs Section
/// Separate tab strip row below the file panels.
struct DuoPanelTabsSection: View {

    let font: NSFont
    let leftPanelWidth: CGFloat
    let containerWidth: CGFloat

    let height: CGFloat

    private var rightPanelWidth: CGFloat {
        max(containerWidth - leftPanelWidth - PanelDividerMetrics.hitAreaWidth, 0)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            TabBarView(panelSide: .left, font: font)
                .padding(.horizontal, 8)
                .frame(width: leftPanelWidth, height: height, alignment: .leading)
            dividerSpacer
            TabBarView(panelSide: .right, font: font)
                .padding(.horizontal, 8)
                .frame(width: rightPanelWidth, height: height, alignment: .leading)
        }
        .frame(width: containerWidth, height: height, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor).opacity(0.78),
                    Color(nsColor: .windowBackgroundColor).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.52))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.58))
                .frame(height: 0.5)
        }
    }

    // MARK: - Divider Spacer

    private var dividerSpacer: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.24))
            .frame(width: PanelDividerMetrics.hitAreaWidth, height: height)
    }
}
