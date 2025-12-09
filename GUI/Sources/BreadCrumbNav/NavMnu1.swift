//
// NavMnu1.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
struct NavMnu1: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide

    // MARK: -
    init(selectedSide: PanelSide) {
        self.panelSide = selectedSide
        log.info("NavMnu1 init for side <<\(selectedSide)>>")
    }

    // MARK: -
    var body: some View {
        log.info(#function)
        return HStack(spacing: 4) {
            ButtonFavTopPanel(selectedSide: panelSide)
        }
        .padding(.leading, 6)
        .task { @MainActor in
            appState.focusedPanel = panelSide
        }
    }
}
