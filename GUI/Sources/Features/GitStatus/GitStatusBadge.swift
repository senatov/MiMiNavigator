// GitStatusBadge.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact semantic badge for read-only Git file state.

import SwiftUI

// MARK: - Git Status Badge
struct GitStatusBadge: View {
    let state: GitFileState

    var body: some View {
        Text(state.badge)
            .font(.system(size: 9.5, weight: .medium, design: .default))
            .foregroundStyle(tint)
            .frame(minWidth: 14, minHeight: 13)
            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(tint.opacity(0.28), lineWidth: 0.6)
            }
            .help("Git: \(state.title)")
            .accessibilityLabel("Git status: \(state.title)")
    }

    private var tint: Color {
        switch state {
            case .modified: return Color(nsColor: .systemOrange)
            case .untracked: return Color(nsColor: .systemGreen)
            case .ignored: return Color(nsColor: .secondaryLabelColor)
            case .conflicted: return Color(nsColor: .systemRed)
        }
    }
}
