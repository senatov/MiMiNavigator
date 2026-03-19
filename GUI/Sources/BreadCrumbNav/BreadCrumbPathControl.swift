//
// EditablePathControl.swift
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
        static var activeBackgroundColor: Color { ColorThemeStore.shared.activeTheme.panelBackground }
        static var inactiveBackgroundColor: Color { DesignTokens.card }
        static let borderOpacity: CGFloat = 0.15
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
            FavoritesButtonSection(selectedSide: panelSide)
            Spacer(minLength: 2)
            BreadCrumbView(selectedSide: panelSide)
                .environment(appState)
            EllipsisMenuSection()
        }
        .frame(height: 30)
        // Background is managed by BreadCrumbControlWrapper — dont overlay here
        .animation(.easeInOut(duration: 0.2), value: isActivePanel)
        // Note: Focus is now managed by BreadCrumbControlWrapper to avoid conflicts
    }
}
