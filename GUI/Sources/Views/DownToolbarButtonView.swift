//
// DownToolbarButtonView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.

import SwiftUI

// MARK:  -
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
        // Only call to makeButton() and wrappers for SRP
        ZStack { makeButton() }
            .frame(minWidth: 120, minHeight: 20)
            .contentShape(.rect(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Builds and configures the toolbar button (macOS 26.1 liquid glass style)
    private func makeButton() -> some View {
        return Button(action: handlePress) {
            Label {
                Text(title)
                    .font(.subheadline)  // Dynamic Type instead of .system(size: 13)
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
            .background(
                // Hover/pressed get ultraThinMaterial, idle gets faint fill
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((isHovered || isPressed) ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.02)))
            )
            .overlay(
                // Primary stroke changes with hover/press, disabled dims
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isPressed
                            ? FilePanelStyle.skyBlauColor.opacity(0.9)
                            : (isHovered ? FilePanelStyle.skyBlauColor.opacity(0.6) : Color.primary.opacity(0.2)),
                        lineWidth: isPressed ? 1.5 : 1
                    )
            )
            .overlay(
                // Inner subtle highlight for glass look
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    .blendMode(.screen)
            )
            .overlay(alignment: .top) {
                // Hairline top separator per Figma macOS 26.1
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 0.5)
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
            }
            .overlay(
                // Focus ring for keyboard nav
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(FilePanelStyle.skyBlauColor.opacity(isFocused ? 0.9 : 0), lineWidth: isFocused ? 2 : 0)
            )
            .shadow(
                color: Color.black.opacity(isPressed ? 0.16 : (isHovered ? 0.10 : 0)),
                radius: isPressed ? 6 : (isHovered ? 5 : 0), x: 0, y: isPressed ? 2 : 1
            )
            .scaleEffect(isPressed ? 0.985 : (isHovered ? 1.005 : 1.0))
            .foregroundStyle(
                isEnabled
                    ? (isHovered ? FilePanelStyle.dirNameColor : FilePanelStyle.dirNameColor)
                    : FilePanelStyle.dirNameColor.opacity(0.5)
            )
            .opacity(isEnabled ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover(perform: handleHover)
        .focusable(true)
        .focused($isFocused)
        .animation(.spring(response: 0.38, dampingFraction: 1.12), value: isHovered)
        .animation(.spring(response: 0.35, dampingFraction: 1.05), value: isPressed)
    }

    // MARK: - handle button press
    private func handlePress() {
        log.debug("DownToolbarButton pressed: \(title)")
        withAnimation(.easeInOut(duration: 0.18)) { isPressed = true }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: 0.22)) { isPressed = false }
        }
        action()
    }

    // MARK: - handle cursor hover
    private func handleHover(_ hovering: Bool) {
        if hovering == isHovered { return }
        log.debug("Hover \(hovering ? "ENTER" : "EXIT") on: \(title)")
        withAnimation(.easeInOut(duration: 0.25)) {
            isHovered = hovering
        }
    }
}
