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
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide

    // MARK: -
    init(selectedSide: PanelSide) {
        // Log removed - too verbose
        self.panelSide = selectedSide
    }

    // MARK: -
    var body: some View {
        // Log removed - too verbose
        return HStack(spacing: 2) {
            NavMnu1(selectedSide: panelSide)
            Spacer(minLength: 2)
            BreadCrumbView(selectedSide: panelSide).environmentObject(appState)
            NavMnu2()
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                .fill(.background)
        )
        // Note: Focus is now managed by BreadCrumbControlWrapper to avoid conflicts
    }
}
