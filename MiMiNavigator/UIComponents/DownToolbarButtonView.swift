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
                    .padding(.vertical, 6)
                    .frame(minWidth: 120, minHeight: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(#colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1)), lineWidth: 2)
                    )
                    .scaleEffect(isPressed ? 0.92 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .help(title)
            .onHover(perform: handleHover)
        }
        .frame(minWidth: 120, minHeight: 20)
        .contentShape(Rectangle())  // Гарантия, что hover обрабатывается
    }

    //MARK: - Обработчик нажатия кнопки
    private func handlePress() {
        log.info(#function)
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

    // MARK: -  Обработчик наведения курсора
    private func handleHover(_ hovering: Bool) {
        log.info(#function + "Hover on '\(title)': \(hovering ? "ENTER" : "EXIT")")
        withAnimation(.easeInOut(duration: 0.4)) {
            isHovered = hovering
        }
    }
}
