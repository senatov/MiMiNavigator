//
// DownToolbarButtonView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.

import SwiftUI

// MARK: -
struct DownToolbarButtonView: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    // MARK: -
    var body: some View {
        ZStack { makeButton() }
            .frame(minWidth: 120, minHeight: 20)
            .contentShape(.rect(cornerRadius: FilePanelStyle.toolbarButtonRadius, style: .continuous))
    }
    
    // MARK: - Computed colors to simplify type-checking
    private var backgroundStyle: AnyShapeStyle {
        (isHovered || isPressed)
            ? AnyShapeStyle(.ultraThinMaterial)
            : AnyShapeStyle(Color.white.opacity(0.02))
    }
    
    private var strokeColor: Color {
        if isPressed {
            return FilePanelStyle.skyBlueColor.opacity(0.9)
        } else if isHovered {
            return FilePanelStyle.skyBlueColor.opacity(0.6)
        } else {
            return Color.primary.opacity(0.2)
        }
    }
    
    private var strokeWidth: CGFloat {
        isPressed ? 1.5 : 1
    }
    
    private var focusRingOpacity: Double {
        isFocused ? 0.9 : 0
    }
    
    private var focusRingWidth: CGFloat {
        isFocused ? 2 : 0
    }
    
    private var shadowOpacity: Double {
        isPressed ? 0.16 : (isHovered ? 0.10 : 0)
    }
    
    private var shadowRadius: CGFloat {
        isPressed ? 6 : (isHovered ? 5 : 0)
    }
    
    private var shadowY: CGFloat {
        isPressed ? 2 : 1
    }
    
    private var buttonScale: CGFloat {
        isPressed ? 0.985 : (isHovered ? 1.005 : 1.0)
    }
    
    private var foregroundColor: Color {
        isEnabled
            ? FilePanelStyle.dirNameColor
            : FilePanelStyle.dirNameColor.opacity(0.5)
    }

    // MARK: - Builds and configures the toolbar button (macOS 26.1 liquid glass style)
    private func makeButton() -> some View {
        Button(action: handlePress) {
            buttonLabel
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover(perform: handleHover)
        .focusable(true)
        .focused($isFocused)
        .focusEffectDisabled()
        .animation(.spring(response: 0.38, dampingFraction: 1.12), value: isHovered)
        .animation(.spring(response: 0.35, dampingFraction: 1.05), value: isPressed)
    }
    
    // MARK: - Button label with all styling
    private var buttonLabel: some View {
        Label {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .alignmentGuide(.firstTextBaseline) { $0[.firstTextBaseline] }
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minWidth: 120, minHeight: 28)
        .background(backgroundRectangle)
        .overlay(primaryStroke)
        .overlay(innerHighlight)
        .overlay(alignment: .top) { topSeparator }
        .overlay(focusRing)
        .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
        .scaleEffect(buttonScale)
        .foregroundStyle(foregroundColor)
        .opacity(isEnabled ? 1 : 0.6)
    }
    
    // MARK: - Background rectangle
    private var backgroundRectangle: some View {
        RoundedRectangle(cornerRadius: FilePanelStyle.toolbarButtonRadius, style: .continuous)
            .fill(backgroundStyle)
    }
    
    // MARK: - Primary stroke
    private var primaryStroke: some View {
        RoundedRectangle(cornerRadius: FilePanelStyle.toolbarButtonRadius, style: .continuous)
            .strokeBorder(strokeColor, lineWidth: strokeWidth)
    }
    
    // MARK: - Inner highlight for glass look
    private var innerHighlight: some View {
        RoundedRectangle(cornerRadius: FilePanelStyle.toolbarButtonRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            .blendMode(.screen)
    }
    
    // MARK: - Top separator per Figma macOS 26.1
    private var topSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 0.5)
            .clipShape(.rect(cornerRadius: FilePanelStyle.toolbarButtonRadius, style: .continuous))
    }
    
    // MARK: - Focus ring for keyboard nav
    private var focusRing: some View {
        RoundedRectangle(cornerRadius: FilePanelStyle.toolbarButtonRadius, style: .continuous)
            .strokeBorder(FilePanelStyle.skyBlueColor.opacity(focusRingOpacity), lineWidth: focusRingWidth)
    }

    // MARK: - Handle button press
    private func handlePress() {
        log.debug("DownToolbarButton pressed: \(title)")
        withAnimation(.easeInOut(duration: 0.18)) { isPressed = true }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: 0.22)) { isPressed = false }
        }
        action()
    }

    // MARK: - Handle cursor hover
    private func handleHover(_ hovering: Bool) {
        if hovering == isHovered { return }
        log.debug("Hover \(hovering ? "ENTER" : "EXIT") on: \(title)")
        withAnimation(.easeInOut(duration: 0.25)) {
            isHovered = hovering
        }
    }
}
