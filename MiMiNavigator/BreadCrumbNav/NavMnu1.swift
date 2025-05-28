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
/// -
struct NavMnu1: View {
    var panelSide: PanelSide

    // MARK: -
    init(panelSide: PanelSide) {
        self.panelSide = panelSide
    }

    // MARK: -
    var body: some View {
        HStack(spacing: 4) {
            FavButtonPopupTopPanel()
        }
        .padding(.leading, 6)
    }
}
