//
//  DownToolbarButtonView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.

import SwiftUI

//  MARK: -
struct DownToolbarButtonView: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    // MARK: -
    var body: some View {
        // Only call to makeButton() and wrappers for SRP
        ZStack {
            makeButton()
        }
        .frame(minWidth: 120, minHeight: 20)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    //  MARK: - Builds and configures the toolbar button (macOS 26.1 liquid glass style)
    private func makeButton() -> some View {
        return Button(action: handlePress) {
            Label {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } icon: {
                Image(systemName: systemImage)
                    .imageScale(.medium)
            }
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: 120, minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        (isHovered || isPressed)
                            ? AnyShapeStyle(.ultraThinMaterial)
                            : AnyShapeStyle(Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isPressed
                            ? FilePanelStyle.skyBlauColor.opacity(0.9)
                            : (isHovered ? FilePanelStyle.skyBlauColor.opacity(0.6) : Color.primary.opacity(0.15)),
                        lineWidth: isPressed ? 2 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isPressed ? 0.18 : (isHovered ? 0.12 : 0)),
                radius: isPressed ? 10 : (isHovered ? 8 : 0),
                x: 0, y: isPressed ? 2 : 1
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.01 : 1.0))
            .foregroundColor(
                isHovered
                    ? Color(#colorLiteral(red: 0.1921568662, green: 0.007843137719, blue: 0.09019608051, alpha: 1))
                    : FilePanelStyle.dirNameColor
            )
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover(perform: handleHover)
        .animation(.spring(response: 0.38, dampingFraction: 1.12), value: isHovered)
        .animation(.spring(response: 0.35, dampingFraction: 1.05), value: isPressed)
    }

    // MARK: - handle button press
    private func handlePress() {
        log.info(#function + " for button '\(title)'")
        withAnimation(.easeInOut(duration: 0.2)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPressed = false
            }
        }
        log.info("Button '\(title)' pressed")
        action()
    }

    // MARK: - handle cursor hover
    private func handleHover(_ hovering: Bool) {
        log.info(#function + "Hover on '\(title)': \(hovering ? "ENTER" : "EXIT")")
        withAnimation(.easeInOut(duration: 0.4)) {
            isHovered = hovering
        }
    }
}
