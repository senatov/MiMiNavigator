//
//  TopMenuButton.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.05.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// A custom-styled button used in the top menu bar
struct TopMenuButton: View {
    let titleStr: String
    let action: () -> Void
    @State private var isHovered = false

    // MARK: -
    var body: some View {
        Button(action: action) {
            Text(titleStr)
                .padding(.horizontal, 30)
                .padding(.vertical, 6)
                .font(.system(size: NSFont.systemFontSize, weight: .regular))
                .foregroundColor(isHovered ? Color.blue.opacity(0.9) : Color.primary)
                .frame(height: 22)
                .background(
                    Group {
                        if isHovered {
                            Color.blue.opacity(0.15)
                        }
                        else {
                            BlurView(material: .constant(NSVisualEffectView.Material.sidebar))
                        }
                    }
                )
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.blue.opacity(isHovered ? 0.8 : 0.4), lineWidth: isHovered ? 1.4 : 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                isHovered = hovering
            }
        }
        .accessibility(label: Text("Top menu button"))
    }
}
