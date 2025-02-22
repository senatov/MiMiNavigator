//
//  DownToolbarButtonView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.

import SwiftUI
import SwiftyBeaver

struct DownToolbarButtonView: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        ZStack {
            Button(action: handlePress) {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minWidth: 120, minHeight: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)  // Фон остается прозрачным
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.5), lineWidth: isHovered ? 3 : 1)  // Тонкая рамка, увеличивается при hover
                            .animation(.easeInOut(duration: 0.4), value: isHovered)
                    )
                    .scaleEffect(isPressed ? 0.92 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .help(title)
            .onHover(perform: handleHover)
        }
        .frame(minWidth: 120, minHeight: 28)
        .contentShape(Rectangle())  // Гарантия, что hover обрабатывается
    }

    /// Обработчик нажатия кнопки
    private func handlePress() {
        LogMan.log.debug("handlePress()")
        withAnimation(.easeInOut(duration: 0.2)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = false
            }
        }
        log.debug("Button '\(title)' pressed")
        action()
    }

    /// Обработчик наведения курсора
    private func handleHover(_ hovering: Bool) {
        LogMan.log.debug("Hover on '\(title)': \(hovering ? "ENTER" : "EXIT")")
        withAnimation(.easeInOut(duration: 0.2)) {
            isHovered = hovering
        }
    }
}
