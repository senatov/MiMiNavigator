//
//  TopMenuBarView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//  Description: SwiftUI component for rendering the top menu bar with dropdown menus and shortcuts.
//

import SwiftUI

struct TopMenuBarView: View {

    var body: some View {
        HStack(spacing: 8) {
            ForEach(menuData.dropLast()) { menu in
                menuView(for: menu)
            }
            Spacer()  // Push Help menu to the right edge
            // Help menu rendered separately
            if let helpMenu = menuData.last {
                Menu {
                    ForEach(helpMenu.items) { item in
                        TopMenuItemView(item: item)
                    }
                } label: {
                    TopMenuButton(titleStr: helpMenu.titleStr) {}
                        .help("Open menu: '\(helpMenu.titleStr)'")
                }
                .buttonStyle(TopMenuButtonStyle())
                .padding(.trailing, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(
            BlurView()
                .clipShape(RoundedRectangle(cornerRadius: 7))
        )
    }

    private func menuView(for menu: MenuCategory) -> some View {
        Menu(menu.titleStr) {
            ForEach(menu.items) { item in
                TopMenuItemView(item: item)
            }
        }
        .help("Open menu: \(menu.titleStr)")
        .buttonStyle(TopMenuButtonStyle())
    }

    // All top-level menu categories are defined here:
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
