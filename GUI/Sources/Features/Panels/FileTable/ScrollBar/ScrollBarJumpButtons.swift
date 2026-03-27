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

    private enum Metrics {
        static let minimumScrollableRows = 50
        static let buttonHeight: CGFloat = 18
        static let buttonWidthInset: CGFloat = 2
        static let containerSpacing: CGFloat = 4
        static let verticalPadding: CGFloat = 4
        static let cornerRadius: CGFloat = 4
        static let borderOpacity: Double = 0.16
        static let borderWidth: CGFloat = 0.5
        static let minimumButtonWidth: CGFloat = 12
        static let symbolSize: CGFloat = 9
    }

    private var shouldShowButtons: Bool {
        rowCount > Metrics.minimumScrollableRows
    }

    private var buttonWidth: CGFloat {
        max(Metrics.minimumButtonWidth, ScrollBarConfig.trackWidth - Metrics.buttonWidthInset)
    }

    var body: some View {
        Group {
            if shouldShowButtons {
                VStack(spacing: Metrics.containerSpacing) {
                    jumpButton(
                        icon: "chevron.up.2",
                        help: "Jump to top (Home)",
                        accessibilityLabel: "Jump to top",
                        action: handleJumpToTop
                    )

                    Spacer(minLength: 0)

                    jumpButton(
                        icon: "chevron.down.2",
                        help: "Jump to bottom (End)",
                        accessibilityLabel: "Jump to bottom",
                        action: handleJumpToBottom
                    )
                }
                .frame(width: ScrollBarConfig.trackWidth)
                .frame(maxHeight: .infinity)
                .padding(.vertical, Metrics.verticalPadding)
            }
        }
    }

    private func jumpButton(
        icon: String,
        help: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Metrics.symbolSize, weight: .semibold))
                .frame(width: buttonWidth, height: Metrics.buttonHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(.primary.opacity(Metrics.borderOpacity), lineWidth: Metrics.borderWidth)
        }
    }

    private func handleJumpToTop() {
        NotificationCenter.default.post(name: .jumpToFirst, object: panelSide)
    }

    private func handleJumpToBottom() {
        NotificationCenter.default.post(name: .jumpToLast, object: panelSide)
    }
}
