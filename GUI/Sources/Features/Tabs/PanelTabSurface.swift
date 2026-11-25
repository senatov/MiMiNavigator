import SwiftUI

// MARK: - Shared Panel Tab Surface
struct PanelTabSurface: View {
    let isActive: Bool
    var isPanelFocused = true
    var isHovered = false
    var compact = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("tabs.appearance.bottomRadius") private var bottomRadius = TabAppearance.bottomRadius
    @AppStorage("tabs.appearance.inactivePanelOpacity") private var inactivePanelOpacity = TabAppearance.inactivePanelOpacity
    @AppStorage("tabs.appearance.focusedBackground") private var focusedBackgroundHex = TabAppearance.focusedBackground
    @AppStorage("tabs.appearance.unfocusedBackground") private var unfocusedBackgroundHex = TabAppearance.unfocusedBackground
    private var tabShape: BottomSheetTabShape { BottomSheetTabShape(bottomRadius: CGFloat(bottomRadius)) }
    // MARK: - Body
    var body: some View {
        if compact {
            compactSurface
                .overlay {
                    compactShape.strokeBorder(
                        isFocusedSelection ? activeBorder.opacity(0.9) : inactiveBorder.opacity(isActive || isHovered ? 0.75 : 0.58),
                        lineWidth: isActive ? 0.85 : 0.75
                    )
                }
        } else {
            surfaceFill
                .shadow(color: tabShadowColor, radius: isFocusedSelection ? 2.8 : isActive ? 1.8 : 1.1, x: 0.7, y: 1)
                .overlay(tabInnerHighlight)
                .overlay(tabBorder)
        }
    }

    // MARK: - Compact Surface
    @ViewBuilder
    private var compactSurface: some View {
        if isActive {
            compactShape
                .fill(selectedBackground.opacity(isPanelFocused ? 0.45 : inactivePanelOpacity * 0.45))
                .glassEffect(.regular.tint(selectedBackground.opacity(isPanelFocused ? 0.7 : inactivePanelOpacity * 0.55)), in: compactShape)
        } else {
            compactShape.fill(background(focused: false).opacity(isHovered ? 0.55 : 0.25))
        }
    }

    // MARK: - Compact Shape
    private var compactShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 2,
            bottomLeadingRadius: CGFloat(bottomRadius),
            bottomTrailingRadius: CGFloat(bottomRadius),
            topTrailingRadius: 2
        )
    }

    // MARK: - Surface Fill
    @ViewBuilder
    private var surfaceFill: some View {
        if isFocusedSelection {
            tabFill
                .glassEffect(.regular.tint(Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.10)), in: tabShape)
        } else {
            tabFill
                .opacity(isPanelFocused ? 1 : inactivePanelOpacity)
                .clipShape(tabShape)
        }
    }
    private var isFocusedSelection: Bool { isActive && isPanelFocused }
    // MARK: - Tab Fill

    @ViewBuilder
    private var tabFill: some View {
        if isActive {
            LinearGradient(
                stops: [
                    .init(color: selectedBackground.opacity(colorScheme == .dark ? 0.68 : 1), location: 0),
                    .init(color: selectedBackground.opacity(colorScheme == .dark ? 0.52 : 0.92), location: 0.58),
                    .init(color: selectedBackground.opacity(colorScheme == .dark ? 0.38 : 0.78), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isHovered {
            LinearGradient(
                stops: [
                    .init(color: selectedBackground.opacity(colorScheme == .dark ? 0.30 : 0.64), location: 0),
                    .init(color: selectedBackground.opacity(colorScheme == .dark ? 0.24 : 0.58), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                stops: [
                    .init(color: selectedBackground.opacity(colorScheme == .dark ? 0.20 : 0.44), location: 0),
                    .init(color: selectedBackground.opacity(colorScheme == .dark ? 0.15 : 0.38), location: 1),
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
                lineWidth: isFocusedSelection ? 1.1 : isActive ? 0.8 : 0.65
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

    private var selectedBackground: Color {
        background(focused: isPanelFocused)
    }

    // MARK: - Appearance Background
    private func background(focused: Bool) -> Color {
        let hex = focused ? focusedBackgroundHex : unfocusedBackgroundHex
        let defaultHex = focused ? TabAppearance.focusedBackground : TabAppearance.unfocusedBackground
        let darkHex = focused ? TabAppearance.darkFocusedBackground : TabAppearance.darkUnfocusedBackground
        return Color(hex: colorScheme == .dark && hex == defaultHex ? darkHex : hex)
            ?? Color(nsColor: .controlBackgroundColor)
    }

    private var inactiveBorder: Color {
        Color(#colorLiteral(red: 0.49, green: 0.52, blue: 0.57, alpha: 1))
    }

}
