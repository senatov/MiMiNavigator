//
//  EditablePathControl.swift
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
        log.info(#function + " for side <<\(selectedSide)>>")
        self.panelSide = selectedSide
    }

    // MARK: -
    var body: some View {
        log.info(#function + " for side <<\(panelSide)>>")
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
        .task { @MainActor in
            appState.focusedPanel = panelSide
        }
    }
}
