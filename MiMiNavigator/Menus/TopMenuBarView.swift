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
            // Left-side menu button with a hamburger icon
            Button(action: toggleMenu) {
                HStack {
                    Image(systemName: "line.horizontal.3")
                }
                .accessibilityLabel("Toggle")
                .background(Color.clear)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
            .background(BlurView())
            ForEach(menuData) { menu in
                Menu {
                    // Populate each menu category with its items
                    ForEach(menu.items) { item in
                        MenuItemView(item: item)
                    }
                } label: {
                    Text(menu.title)
                        .frame(minWidth: 80)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(NSColor.windowBackgroundColor))  // Фон как у стандартной панели
                        .cornerRadius(5)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Menu Data (Fake Data Layer)
    private var menuData: [MenuCategory] {
        // Hardcoding menu categories (like an old-school `switchboard`)
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
