//
// BreadCrumbPathControl.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

// MARK: - A view displaying a breadcrumb-style editable path bar with panel navigation menus.
struct BreadCrumbPathControl: View {
    @Environment(AppState.self) var appState
    let panelSide: FavPanelSide

    // MARK: - Is Active Panel
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    // MARK: - Init
    init(selectedSide: FavPanelSide) {
        self.panelSide = selectedSide
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: 2) {
            breadcrumbMenuSection
            breadcrumbPathSection
            breadcrumbUtilitySection
            ellipsisSection
        }
        .frame(height: 30)
        // Background is managed by BreadCrumbControlWrapper — dont overlay here
        .animation(.easeInOut(duration: 0.2), value: isActivePanel)
        // Note: Focus is now managed by BreadCrumbControlWrapper to avoid conflicts
    }

    // MARK: - Sections

    private var breadcrumbMenuSection: some View {
        BreadCrumbToolBar(selectedSide: panelSide, content: .navigation)
            .padding(.leading, 6)
    }

    private var breadcrumbPathSection: some View {
        BreadCrumbView(selectedSide: panelSide)
            .environment(appState)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
    }

    private var breadcrumbUtilitySection: some View {
        BreadCrumbToolBar(selectedSide: panelSide, content: .utilities)
    }

    private var ellipsisSection: some View {
        EllipsisMenuSection()
    }
}
