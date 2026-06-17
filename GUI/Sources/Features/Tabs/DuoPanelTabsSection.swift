// DuoPanelTabsSection.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Detached bottom tab strip aligned with the dual file panels.

import FileModelKit
import SwiftUI

// MARK: - Duo Panel Tabs Section
/// Separate tab strip row below the file panels.
struct DuoPanelTabsSection: View {
    static let height: CGFloat = 31

    let leftPanelWidth: CGFloat
    let containerWidth: CGFloat

    private var rightPanelWidth: CGFloat {
        max(containerWidth - leftPanelWidth - PanelDividerMetrics.hitAreaWidth, 0)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            TabBarView(panelSide: .left)
                .padding(.horizontal, 8)
                .frame(width: leftPanelWidth, height: Self.height, alignment: .leading)
            dividerSpacer
            TabBarView(panelSide: .right)
                .padding(.horizontal, 8)
                .frame(width: rightPanelWidth, height: Self.height, alignment: .leading)
        }
        .frame(width: containerWidth, height: Self.height, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    // MARK: - Divider Spacer

    private var dividerSpacer: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.35))
            .frame(width: PanelDividerMetrics.hitAreaWidth, height: Self.height)
    }
}
