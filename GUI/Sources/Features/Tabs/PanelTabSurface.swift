import SwiftUI

// MARK: - Shared Panel Tab Surface
struct PanelTabSurface: View {
    let isActive: Bool
    var isPanelFocused = true
    var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    private var tabShape: BottomSheetTabShape { BottomSheetTabShape() }
    var body: some View {
        tabFill
            .clipShape(tabShape)
            .shadow(color: tabShadowColor, radius: isActive ? 1.8 : 1.1, x: 0.7, y: 1)
            .overlay(tabInnerHighlight)
            .overlay(tabBorder)
    }
    // MARK: - Tab Fill

    @ViewBuilder
    private var tabFill: some View {
        if isActive {
            LinearGradient(
                stops: [
                    .init(color: activeFillTop.opacity(colorScheme == .dark ? 0.68 : 1), location: 0),
                    .init(color: activeFillMid.opacity(colorScheme == .dark ? 0.52 : 0.98), location: 0.58),
                    .init(color: activeFillFoot.opacity(colorScheme == .dark ? 0.38 : 0.94), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isHovered {
            LinearGradient(
                stops: [
                    .init(color: inactiveFillTop.opacity(colorScheme == .dark ? 0.30 : 0.64), location: 0),
                    .init(color: inactiveFillFoot.opacity(colorScheme == .dark ? 0.24 : 0.58), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: inactiveFillTop.opacity(colorScheme == .dark ? 0.20 : 0.44), location: 0),
                    .init(color: inactiveFillFoot.opacity(colorScheme == .dark ? 0.15 : 0.38), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var tabShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? isActive ? 0.32 : 0.20 : isActive ? 0.18 : 0.10)
    }

    private var tabBorder: some View {
        tabShape
            .strokeBorder(
                isActive
                    ? activeBorder.opacity(isPanelFocused ? 0.94 : 0.72)
                    : inactiveBorder.opacity(isHovered ? 0.72 : 0.52),
                lineWidth: isActive ? 0.8 : 0.65
            )
    }

    private var tabInnerHighlight: some View {
        tabShape.fill(
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(colorScheme == .dark ? 0.10 : isActive ? 0.52 : 0.30), location: 0),
                    .init(color: Color.white.opacity(colorScheme == .dark ? 0.025 : 0.07), location: 0.38),
                    .init(color: Color.clear, location: 0.68),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(1)
        .allowsHitTesting(false)
    }

    private var activeBorder: Color {
        Color(#colorLiteral(red: 0.25, green: 0.58, blue: 0.93, alpha: 1))
    }

    private var activeFillTop: Color {
        Color(#colorLiteral(red: 0.965, green: 0.984, blue: 1.0, alpha: 1))
    }

    private var activeFillMid: Color {
        Color(#colorLiteral(red: 0.918, green: 0.949, blue: 0.986, alpha: 1))
    }

    private var activeFillFoot: Color {
        Color(#colorLiteral(red: 0.82, green: 0.875, blue: 0.95, alpha: 1))
    }

    private var inactiveFillTop: Color {
        Color(#colorLiteral(red: 0.91, green: 0.925, blue: 0.946, alpha: 1))
    }

    private var inactiveFillFoot: Color {
        Color(#colorLiteral(red: 0.79, green: 0.82, blue: 0.86, alpha: 1))
    }

    private var inactiveBorder: Color {
        Color(#colorLiteral(red: 0.49, green: 0.52, blue: 0.57, alpha: 1))
    }

}
