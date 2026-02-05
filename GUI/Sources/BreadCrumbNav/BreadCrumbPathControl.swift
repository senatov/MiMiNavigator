//
// EditablePathControl.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - A view displaying a breadcrumb-style editable path bar with panel navigation menus.
struct BreadCrumbPathControl: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide

    // MARK: - Design Constants
    private enum Design {
        static let cornerRadius: CGFloat = 8
        static let activeBackgroundColor = Color.yellow.opacity(0.07)
        static let inactiveBackgroundColor = Color.clear
        static let borderOpacity: CGFloat = 0.15
    }

    // MARK: - Is Active Panel
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    // MARK: -
    init(selectedSide: PanelSide) {
        self.panelSide = selectedSide
    }

    // MARK: -
    var body: some View {
        return HStack(spacing: 2) {
            FavoritesButtonSection(selectedSide: panelSide)
            Spacer(minLength: 2)
            BreadCrumbView(selectedSide: panelSide)
                .environment(appState)
            EllipsisMenuSection()
        }
        .background(
            RoundedRectangle(cornerRadius: Design.cornerRadius)
                .fill(isActivePanel ? Design.activeBackgroundColor : Design.inactiveBackgroundColor)
        )
        .background(
            RoundedRectangle(cornerRadius: Design.cornerRadius)
                .strokeBorder(Color.secondary.opacity(Design.borderOpacity), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isActivePanel)
        // Note: Focus is now managed by BreadCrumbControlWrapper to avoid conflicts
    }
}
