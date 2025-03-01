//
//  TopMenuBarView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//  Description: SwiftUI component for rendering the top menu bar with dropdown menus and shortcuts.
//
import SwiftUI

struct TopMenuBarView: View {
    @Binding var isShowMenu: Bool  // Toggle state for showing/hiding menu
    var toggleMenu: () -> Void  // Action to toggle the menu

    var body: some View {
        HStack(spacing: 8) {
            // Кнопка "гамбургер"
            Button(action: toggleMenu) {
                Image(systemName: "line.horizontal.3")
                    .frame(width: 18, height: 18)
            }
            .accessibilityLabel("Toggle")
            .background(BlurView())
            .padding(.horizontal, 15)
            .padding(.vertical, 4)

            // Остальные пункты меню (кроме Help)
            ForEach(menuData.dropLast()) { menu in
                Menu {
                    ForEach(menu.items) { item in
                        TopMenuItemView(item: item)
                    }
                } label: {
                    Text(menu.title)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .font(.system(size: NSFont.systemFontSize, weight: .regular))
                        .foregroundColor(Color.primary)
                        .frame(height: 22)
                }
                .buttonStyle(TopMenuButtonStyle())
            }
            Spacer()  // Отделяем Help от остальных
            // Последний пункт "Help"
            if let helpMenu = menuData.last {
                Menu {
                    ForEach(helpMenu.items) { item in
                        TopMenuItemView(item: item)
                    }
                } label: {
                    Text(helpMenu.title)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .font(.system(size: NSFont.systemFontSize, weight: .regular))
                        .foregroundColor(Color.primary)
                        .frame(height: 22)
                }
                .buttonStyle(TopMenuButtonStyle())
                .padding(.trailing, 1)  // Отступ 1px от правого края
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)  // Растягиваем на всю ширину
        .padding(.horizontal, 20)
        .background(BlurView())  // Одинаковый фон для всей панели
    }

    // MARK: - Menu Data
    private var menuData: [MenuCategory] {
        [
            filesMenuCategory,
            markMenuCategory,
            commandMenuCategory,
            netMenuCategory,
            showMenuCategory,
            configMenuCategory,
            startMenuCategory,
            helpMenuCategory,
        ]
    }
}

// MARK: - Menu Button Style
struct TopMenuButtonStyle: ButtonStyle {
    @State private var isHovered = false  // Отслеживаем наведение курсора

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 30)  // Уменьшаем отступы
            .padding(.vertical, 3)
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
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(isHovered ? 0.8 : 0.4), lineWidth: isHovered ? 1.4 : 1)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering  // Обновляем состояние при наведении
                }
            }
    }
}
