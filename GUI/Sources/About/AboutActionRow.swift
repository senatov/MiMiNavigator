// AboutActionRow.swift
// MiMiNavigator

import AppKit
import SwiftUI

// MARK: - About Action Row
struct AboutActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let iconTint: Color
    let url: String
    @State private var isHovered = false

    var body: some View {
        Button {
            guard let destination = URL(string: url) else { return }
            NSWorkspace.shared.open(destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(iconTint)
                    .frame(width: 20, height: 20)
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1, height: 25)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DownToolbarGlassButtonStyle(isHovered: isHovered, horizontalPadding: 10, verticalPadding: 8, raised: true))
        .onHover { isHovered = $0 }
        .keyboardFocusable()
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(subtitle)")
    }
}
