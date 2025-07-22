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
    let panelSide: PanelSide

    init(selectedSide: PanelSide) {
        log.info("NavMnu1 init" + " for side \(selectedSide)")
        self.panelSide = selectedSide
    }


    // MARK: -
    var body: some View {
        log.info(#function)
        return HStack(spacing: 4) {
            ButtonFavTopPanel(selectedSide: panelSide)
        }
        .padding(.leading, 6)
    }
}
