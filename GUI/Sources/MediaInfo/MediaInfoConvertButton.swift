//
//  MediaInfoConvertButton.swift
//  MiMiNavigator
//
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - MediaInfoConvertButton

struct MediaInfoConvertButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                .lineLimit(1)
                .frame(minWidth: 118)
        }
        .buttonStyle(
            DownToolbarGlassButtonStyle(
                isHovered: isHovered,
                tint: .accentColor,
                horizontalPadding: 16,
                verticalPadding: 7,
                raised: true
            )
        )
        .disabled(!isEnabled)
        .keyboardFocusable()
        .help("Convert")
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                isHovered = hovering
            }
        }
    }

}
