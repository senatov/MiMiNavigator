//
//  NavMnu1.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import SwiftyBeaver

// MARK: -
struct NavMnu1: View {
    @EnvironmentObject var appState: AppState

    // MARK: -
    var body: some View {
        HStack(spacing: 4) {
            ButtonTopPanelL()
            //ButtonTopPanelR()
            //if !appState.showFavButtonsL { ButtonTopPanelL() }
            //if !appState.showFavButtonsR { ButtonTopPanelR() }
        }
        .padding(.leading, 6)
    }
}
