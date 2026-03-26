// ScrollBarJumpButtons.swift
// MiMiNavigator
//
// Description: Glass-style jump-to-edge buttons flush against the scrollbar track.
//              Appear only when file list exceeds threshold row count.

import FavoritesKit
import FileModelKit
import SwiftUI


// MARK: - ScrollBarJumpButtons

/// Jump-to-top / jump-to-bottom pill buttons aligned with the scrollbar column.
struct ScrollBarJumpButtons: View {
    let panelSide: FavPanelSide
    let rowCount: Int

    /// Minimum row count before buttons appear.
    private static let visibilityThreshold = 50

    /// Height reserved to skip the sticky header zone.
    private static let headerAreaHeight: CGFloat = 26


    var body: some View {
        if rowCount > Self.visibilityThreshold {
            VStack(spacing: 0) {
                Color.clear.frame(height: Self.headerAreaHeight)

                glassJumpButton(icon: "chevron.up.2") {
                    NotificationCenter.default.post(name: .jumpToFirst, object: panelSide)
                }
                .help("Jump to top (Home)")

                Spacer(minLength: 0)

                glassJumpButton(icon: "chevron.down.2") {
                    NotificationCenter.default.post(name: .jumpToLast, object: panelSide)
                }
                .help("Jump to bottom (End)")
            }
            .frame(width: ScrollBarConfig.trackWidth)
            .padding(.trailing, 0)
        }
    }


    /// Translucent pill flush with scrollbar track. Blends with the glass chrome.
    private func glassJumpButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: ScrollBarConfig.trackWidth - 2, height: 18)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
