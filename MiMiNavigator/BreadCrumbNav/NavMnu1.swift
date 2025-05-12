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
    var selectedDir: SelectedDir
    var panelSide: PanelSide

    var body: some View {
        HStack(spacing: 4) {
            FavButtonPopupTopPanel(selectedDir: selectedDir, panelSide: panelSide)
        }
        .padding(.leading, 6)
    }
}
