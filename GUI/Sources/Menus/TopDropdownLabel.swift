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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.94))
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(.rect(cornerRadius: 7))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.72), lineWidth: 0.8)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.32), lineWidth: 0.6)
                .mask(alignment: .top) {
                    Rectangle()
                        .frame(height: 9)
                }
        }
        .shadow(color: Color.black.opacity(0.14), radius: 2, y: 1)
    }
}
