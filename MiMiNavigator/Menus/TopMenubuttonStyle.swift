//
//  TopMenuBarStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
struct TopMenuButtonStyle: ButtonStyle {
    @State private var isHovered = false  // Отслеживаем наведение курсора
    // MARK: -
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 30)  // Уменьшаем отступы
            .padding(.vertical, 6)
            .font(.system(size: NSFont.systemFontSize, weight: .regular))
            .foregroundColor(isHovered ? Color.blue.opacity(0.9) : Color.primary)  // Чёткий тёмно-синий цвет
            .background(
                Group {
                    if isHovered {
                        Color.blue.opacity(0.15)  // Лёгкий голубой фон при наведении
                    } else {
                        BlurView()  // Обычный фон
                    }
                }
            )
            .frame(height: 22)  // Ограничиваем высоту
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.blue.opacity(isHovered ? 0.8 : 0.4), lineWidth: isHovered ? 1.4 : 1)
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                    isHovered = hovering
                }

            }
            .accessibility(label: Text("Верхний меню"))
    }
}
