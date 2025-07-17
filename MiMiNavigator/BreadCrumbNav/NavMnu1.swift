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
        if !appState.showFavButtonsL {
            HStack(spacing: 4) {
                ButtonTopPanelLeft()
            }
            .padding(.leading, 6)
            .onAppear {
                if !appState.showFavButtonsL {
                    appState.showFavButtonsL = true
                }
            }
        }
        if !appState.showFavButtonsR {
            HStack(spacing: 4) {
                ButtonTopPanelRight()
            }
            .padding(.leading, 6)
            .onAppear {
                if !appState.showFavButtonsR {
                    appState.showFavButtonsR = true
                }
            }
        }

    }
}
