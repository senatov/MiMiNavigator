    //
    //  TopMenuBarView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 16.10.24.
    //  Description: SwiftUI component for rendering the top menu bar with dropdown menus and shortcuts.
    //

import SwiftUI

struct TopMenuBarView: View {
        // MARK: -
    var body: some View {
        log.info(#function)
        return HStack(spacing: 8) {
            ForEach(menuData.dropLast()) { menu in
                menuView(for: menu)
            }
            Spacer()  // Push Help menu to the right edge Help menu rendered separately
            if let helpMenu = menuData.last {
                Menu {
                    ForEach(helpMenu.items) { item in
                        TopMenuItemView(item: item)
                    }
                } label: {
                    Text(helpMenu.title)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .font(.system(size: NSFont.systemFontSize, weight: .regular))
                        .foregroundColor(Color.primary)
                        .frame(height: 22)
                        .help("Open menu: '\(helpMenu.title)'")
                }
                .buttonStyle(TopMenuButtonStyle())
                .padding(.trailing, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(
            // Minimal BlurView has no parameters
            BlurView()
                .clipShape(RoundedRectangle(cornerRadius: 7))
        )
    }
        // MARK: -
    private func menuView(for menu: MenuCategory) -> some View {
            // Explicit return for clarity
        return Menu(menu.title) {
            ForEach(menu.items) { item in
                TopMenuItemView(item: item)
            }
        }
        .help("Open menu: \(menu.title)")
        .buttonStyle(TopMenuButtonStyle())
    }
    
        // MARK: - All top-level menu categories are defined here:
    private var menuData: [MenuCategory] {
            // Explicit return for clarity
        return [
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
