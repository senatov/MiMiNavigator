// TopDropdownLabel.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared emphasized label for top-menu dropdown controls.

import AppKit
import SwiftUI

// MARK: - Top Dropdown Label
struct TopDropdownLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    // MARK: - Body
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.32), Color.white.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(.rect(cornerRadius: 9))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.38), lineWidth: 0.7)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.48), lineWidth: 0.6)
                .mask(alignment: .top) {
                    Rectangle()
                        .frame(height: 10)
                }
        }
        .shadow(color: Color.black.opacity(0.07), radius: 2, y: 1)
    }
}
