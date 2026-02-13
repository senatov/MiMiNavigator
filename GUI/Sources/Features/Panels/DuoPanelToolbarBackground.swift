//
// DuoPanelToolbarBackground.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

/// Reusable toolbar background (macOS HIG: clean separator, no glass)
struct DuoPanelToolbarBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .windowBackgroundColor))
            // Single top separator line — system color, no gradient
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
            }
    }
}
