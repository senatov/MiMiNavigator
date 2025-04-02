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
    @State private var isHovering = false
    @State private var showTooltip = false
    var toggleMenu: () -> Void  // Action to toggle the menu

    var body: some View {
        HStack(spacing: 8) {
            // Кнопка "гамбургер"
            Button(action: toggleMenu) {
                Image(systemName: "line.horizontal.3")
                    .frame(width: 18, height: 18)
            }
            .help("external links")
            .accessibilityLabel("Toggle")
            .background(BlurView())
            .padding(.horizontal, 15)
            .padding(.vertical, 4)

            // Остальные пункты меню (кроме Help)
            ForEach(menuData.dropLast()) { menu in
                ZStack(alignment: .topLeading) {
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
                            .help("some Buttons")
                            .onHover { hovering in
                                isHovering = hovering
                                if hovering {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if isHovering && showTooltip {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showTooltip = true
                                            }
                                        }
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showTooltip = false
                                    }
                                }
                            }
                    }

                    if showTooltip {
                        PrettyTooltip(text: "Меню \(menu.title)")
                            .offset(x: 10, y: -34)
                            .transition(.opacity.combined(with: .scale))
                            .zIndex(1)
                    }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct TopMenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        TopMenuBarView(isShowMenu: .constant(true), toggleMenu: {})
            .frame(height: 40)
    }
}
