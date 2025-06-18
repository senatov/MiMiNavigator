//
//  NavMnu2.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import SwiftyBeaver

// MARK: -
struct NavMnu2: View {

    @EnvironmentObject var appState: AppState

    // MARK: --
    var body: some View {
        Menu {
            Button("Properties", action: handleProperties)
            Button("Open in Finder", action: handleOpenInFinder)
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Private handlers
    private func handleProperties() {
        log.info(#function)
        let selected = appState.getSelectedDir()
        log.info("Selected dir path: \(selected)")
    }

    // MARK: -
    private func handleOpenInFinder() {
        log.info(#function)
        let selected = appState.getSelectedDir()
        log.info("Opening path: \(selected)")
    }
}
