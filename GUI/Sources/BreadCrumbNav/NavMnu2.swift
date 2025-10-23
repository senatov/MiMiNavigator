//
//  NavMnu2.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
struct NavMnu2: View {
    @EnvironmentObject var appState: AppState

    // MARK: --
    var body: some View {
        log.info(#function)
        return Menu {
            Button("Properties", action: handleProperties)
            Button("Open in Finder", action: handleOpenInFinder)
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .symbolEffect(.scale)
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Private handlers
    private func handleProperties() {
        log.info(#function)
        let selected = appState.selectedDir
        log.info("Selected dir path: \(selected)")
    }

    // MARK: -
    private func handleOpenInFinder() {
        log.info(#function)
        let selected = appState.selectedDir
        log.info("Opening path: \(selected)")
    }
}
