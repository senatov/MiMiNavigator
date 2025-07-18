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
        log.info(#function)
        return HStack(spacing: 4) {
            ButtonTopPanel()
        }
        .padding(.leading, 6)
    }
}
