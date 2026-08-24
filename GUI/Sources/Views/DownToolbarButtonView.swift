//
// DownToolbarButtonView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.

import SwiftUI

// MARK: -

/// Compact Commander-style action button for the persistent bottom command bar.
struct DownToolbarButtonView: View {
    let title: String
    let systemImage: String
    let imageName: String?
    let action: () -> Void
    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: -

    init(title: String, systemImage: String, imageName: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.imageName = imageName
        self.action = action
    }
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: 6) {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 14)
                }
                Text(title)
            }
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 76)
        }
        .buttonStyle(DownToolbarGlassButtonStyle(isHovered: isHovered))
        .onHover { hovering in
            if reduceMotion { isHovered = hovering }
            else { withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering } }
        }
        .keyboardFocusable()
        .accessibilityLabel(title)
        .help(title)
    }
}

struct DownToolbarGlassButtonStyle: ButtonStyle {
    let isHovered: Bool
    var tint: Color? = nil
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 6
    var raised: Bool = false
    var isSelected: Bool = false

    // MARK: -

    func makeBody(configuration: Configuration) -> some View {
        DownToolbarGlassButtonBody(
            configuration: configuration,
            isHovered: isHovered,
            tint: tint,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            raised: raised,
            isSelected: isSelected
        )
    }
}

// MARK: - DownToolbarGlassButtonBody

private struct DownToolbarGlassButtonBody: View {
    let configuration: DownToolbarGlassButtonStyle.Configuration
    let isHovered: Bool
    let tint: Color?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let raised: Bool
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var isPressed: Bool {
        configuration.isPressed
    }

    private var scale: CGFloat {
        state == .pressed ? 0.985 : 1.0
    }

    private var state: SemanticControlState {
        .resolve(
            isEnabled: isEnabled,
            isPressed: isPressed,
            isSelected: isSelected,
            isFocused: isFocused,
            isHovered: isHovered
        )
    }

    private var shadowOpacity: Double {
        switch state {
        case .disabled: return 0.04
        case .pressed: return 0.10
        case .hovered, .focused, .selected: return raised ? 0.26 : 0.18
        case .normal: return raised ? 0.20 : 0.12
        }
    }

    private var shadowRadius: CGFloat {
        isPressed ? 0.5 : (isHovered ? (raised ? 3.5 : 3) : (raised ? 2.25 : 1.5))
    }

    private var shadowYOffset: CGFloat {
        isPressed ? 0.5 : (raised ? 2 : 1.5)
    }

    private var borderOpacity: Double {
        switch state {
        case .disabled: return 0.10
        case .pressed: return 0.38
        case .hovered: return raised ? 0.54 : 0.42
        case .focused, .selected: return raised ? 0.44 : 0.32
        case .normal: return raised ? 0.34 : 0.22
        }
    }

    var body: some View {
        configuration.label
            .font(DesignTokens.Typography.hotKey)
            .foregroundStyle(Color.primary.opacity(contrast == .increased ? 1 : (isPressed ? 0.96 : 0.90)))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background { backgroundLayer }
            .overlay { buttonBorder }
            .overlay(alignment: .top) { topHighlight }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)
            .scaleEffect(scale)
            .opacity(state == .disabled ? 0.52 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
            .focusEffectDisabled()
    }

    private var backgroundLayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isPressed
                            ? [Color.black.opacity(0.10), Color.white.opacity(0.12)]
                            : [Color.white.opacity(isHovered ? 0.76 : (raised ? 0.66 : 0.56)), Color.primary.opacity(isHovered ? 0.12 : (raised ? 0.11 : 0.075))],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            tintLayer
        }
    }

    private var topHighlight: some View {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.control - 0.5, style: .continuous)
            .strokeBorder(Color.white.opacity(isPressed ? 0.10 : (raised ? 0.72 : 0.56)), lineWidth: raised ? 1 : 0.75)
            .padding(0.75)
            .mask(alignment: .top) {
                Rectangle().frame(height: 12)
            }
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var tintLayer: some View {
        if let tint {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                .fill(tint.opacity(state == .pressed ? 0.28 : ((state == .focused || state == .selected) ? 0.34 : 0.16)))
        }
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
            .strokeBorder(
                state == .focused ? Color.accentColor.opacity(0.72) : Color.black.opacity(borderOpacity),
                lineWidth: state == .focused ? DesignTokens.Control.focusBorderWidth : (raised ? DesignTokens.Control.raisedBorderWidth : DesignTokens.Control.borderWidth)
            )
    }

}
