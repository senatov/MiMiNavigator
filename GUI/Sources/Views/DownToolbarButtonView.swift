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
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .keyboardFocusable()
        .help(title)
    }
}

struct DownToolbarGlassButtonStyle: ButtonStyle {
    let isHovered: Bool
    var tint: Color? = nil
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 6

    // MARK: -

    func makeBody(configuration: Configuration) -> some View {
        DownToolbarGlassButtonBody(
            configuration: configuration,
            isHovered: isHovered,
            tint: tint,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
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
    @Environment(\.isFocused) private var isFocused

    private var isPressed: Bool {
        configuration.isPressed
    }

    private var scale: CGFloat {
        isPressed ? 0.985 : 1.0
    }

    private var shadowOpacity: Double {
        isPressed ? 0.10 : (isHovered ? 0.08 : 0.035)
    }

    private var shadowRadius: CGFloat {
        isPressed ? 1 : (isHovered ? 2 : 1)
    }

    private var shadowYOffset: CGFloat {
        isPressed ? 0 : 1
    }

    private var borderOpacity: Double {
        isPressed ? 0.28 : (isHovered ? 0.24 : 0.14)
    }

    private var glassOpacity: Double {
        isPressed ? 0.18 : (isHovered ? 0.12 : 0.055)
    }

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary.opacity(isPressed ? 0.96 : 0.90))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background { backgroundLayer }
            .overlay { buttonBorder }
            .compositingGroup()
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)
            .scaleEffect(scale)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .focusEffectDisabled()
    }

    private var backgroundLayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(glassOpacity))
            tintLayer
        }
    }

    @ViewBuilder
    private var tintLayer: some View {
        if let tint {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(isPressed ? 0.28 : (isFocused ? 0.34 : 0.16)))
        }
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(Color(nsColor: .separatorColor).opacity(borderOpacity), lineWidth: 0.75)
    }

}
