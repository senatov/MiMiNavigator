// ToolbarButton.swift
// A reusable toolbar button component with customizable title, icon, and action.
// Created by Iakov Senatov

import SwiftUI
import SwiftyBeaver

struct TB_Button_IS: View {
    @State private var isHighlighted = false  // Состояние для отслеживания цвета кнопки
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
            
                // Таймер для возврата к белому цвету через 1.5 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isHighlighted = false // Возвращаем цвет к белому
                }
            }
        }) {
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.headline)
                        .foregroundColor(isHighlighted ? Color.orange : Color.black)
                        .scaleEffect(isPressed ? 0.8 : 1.0)
                        .shadow(color: isHighlighted ? Color.orange.opacity(0.7) : Color.clear, radius: 2, x: 0, y: 2)
                }
                Text(title)
                    .fontWeight(.medium)
                    .foregroundColor(isHighlighted ? Color.yellow : Color.black)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .shadow(color: isHighlighted ? Color.yellow.opacity(0.6) : Color.clear, radius: 2, x: 0, y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.gray.opacity(0.3)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.gray.opacity(0.4), radius: 6, x: 0, y: 5)
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
