//
// DownToolbarButtonView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.

import SwiftUI

// MARK:  -
/// Bottom toolbar button — native macOS bordered bezel with visible edges
struct DownToolbarButtonView: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovered: Bool = false

    // MARK: -
    var body: some View {
        Button(action: {
            action()
        }) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 90)
                .foregroundStyle(Color.primary.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .tint(Color.gray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .shadow(color: Color.black.opacity(isHovered ? 0.18 : 0.10), radius: isHovered ? 10 : 6, y: isHovered ? 5 : 3)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .focusable(false)
        .help(title)
    }
}
