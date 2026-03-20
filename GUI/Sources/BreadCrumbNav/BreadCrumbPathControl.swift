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
    let panelSide: PanelSide

    // MARK: - Design Constants
    @MainActor private enum Design {
        static let cornerRadius: CGFloat = 8
    }

    // MARK: - Is Active Panel
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    // MARK: - Init
    init(selectedSide: PanelSide) {
        self.panelSide = selectedSide
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: 2) {
            breadcrumbMenuSection()
            spacerSection()
            breadcrumbPathSection()
            ellipsisSection()
        }
        .frame(height: 30)
        // Background is managed by BreadCrumbControlWrapper — dont overlay here
        .animation(.easeInOut(duration: 0.2), value: isActivePanel)
        // Note: Focus is now managed by BreadCrumbControlWrapper to avoid conflicts
    }

    // MARK: - Sections

    private func breadcrumbMenuSection() -> some View {
        BreadCrumbMnu(selectedSide: panelSide)
    }

    private func spacerSection() -> some View {
        Spacer(minLength: 2)
    }

    private func breadcrumbPathSection() -> some View {
        BreadCrumbView(selectedSide: panelSide)
            .environment(appState)
    }

    private func ellipsisSection() -> some View {
        EllipsisMenuSection()
    }
}
