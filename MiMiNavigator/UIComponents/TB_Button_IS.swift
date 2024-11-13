// ToolbarButton.swift
// A reusable toolbar button component with customizable title, icon, and action.
// Created by Iakov Senatov

import SwiftUI
import SwiftyBeaver

struct TB_Button_IS: View {
    @State private var isHighlighted = false // Состояние для отслеживания цвета кнопки
    let title: String
    let icon: String? // Optional icon name from SF Symbols or custom icon
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
                isHighlighted = true // Устанавливаем цвет в оранжевый при нажатии
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                action()
            }

            // Таймер для возврата к исходному цвету через 1.5 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isHighlighted = false // Возвращаем цвет к исходному
                }
            }
        }) {
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.headline)
                        .foregroundColor(
                            isHighlighted ? Color.orange : Color.indigo)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }
                Text(title)
                    .fontWeight(.light)
                    .foregroundColor(isHighlighted ? Color.orange : Color.black)
                    // Черный цвет для неактивного состояния
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.gray.opacity(0.3)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.gray.opacity(0.4), radius: 6, x: 0, y: 5) // Тень только на фоне кнопки
            .scaleEffect(isPressed ? 0.95 : 1.0) // Scale effect when pressed
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isPressed)
        }
        .buttonStyle(.borderless)
    }
}

// Пример для превью
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TB_Button_IS(title: "Settings", icon: "switch.2") {
            log.debug("Settings button tapped")
        }.buttonStyle(.bordered)
    }
}
