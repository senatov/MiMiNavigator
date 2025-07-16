//
//  TopMenuBarStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
struct TopMenuButtonStyle: ButtonStyle {

    @State private var isHovered = false  // Tracks mouse hover state

    // MARK: -
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 30)  // Reduced horizontal padding
            .padding(.vertical, 6)
            .font(.system(size: NSFont.systemFontSize, weight: .regular))
            .foregroundColor(isHovered ? Color.blue.opacity(0.9) : Color.primary)  // Crisp dark blue color on hover
            .background(
                Group {
                    if isHovered {
                        Color.blue.opacity(0.15)  // Light blue background on hover
                    }
                    else {
                        BlurView(material: .constant(NSVisualEffectView.Material.sidebar))
                    }
                }
            )
            .frame(height: 22)  // Fixed height
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.blue.opacity(isHovered ? 0.8 : 0.4), lineWidth: isHovered ? 1.4 : 1)
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                    isHovered = hovering
                }
            }
            .accessibility(label: Text("Top menu"))
    }
}
