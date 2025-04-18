//
//  ButtonNavOnBreadCamp.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 19.04.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

struct ButtonNavOnBreadCamp: View {
    @State private var showFavTreePopup = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                log.debug("Back: navigating to previous directory")
            }) {
                Image(systemName: "arrowshape.backward")
            }
            .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)

            Button(action: {
                log.debug("Forward: navigating to next directory")
            }) {
                Image(systemName: "arrowshape.right")
            }
            .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)
            .disabled(true)

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    log.debug("Navigation between favorites")
                    showFavTreePopup = true
                }
            }) {
                Image(systemName: "menucard")
            }
            .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)
            .help("Go up to directory Menu")
            .buttonStyle(.plain)
            .sheet(isPresented: $showFavTreePopup) {
                TotalCommanderResizableView().buildFavTreeMenu()
            }
        }
    }
}


