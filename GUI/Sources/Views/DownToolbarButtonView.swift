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

    // MARK: - -
    var body: some View {
        // Only call to makeButton() and wrappers for SRP
        ZStack {
            makeButton()
        }
        .frame(minWidth: 120, minHeight: 20)
        .contentShape(Rectangle())  // Ensure hover is handled
    }

    //  MARK: - Builds and configures the toolbar button
    private func makeButton() -> some View {
        // Log button creation for debugging
        log.info(#function + " for button '\(title)'")
        return Button(action: handlePress) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minWidth: 120, minHeight: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(FilePanelStyle.skyBlauColor, lineWidth: 2)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .foregroundColor(
                    isHovered
                        ? Color(#colorLiteral(red: 0.1921568662, green: 0.007843137719, blue: 0.09019608051, alpha: 1))
                        : FilePanelStyle.dirNameColor)
        }
        .buttonStyle(PlainButtonStyle())
        .help(title)
        .onHover(perform: handleHover)
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
