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
                // Render all menus except the last one (Help)
            ForEach(Array(menuData.dropLast())) { menu in
                Menu {
                    ForEach(menu.items) { item in
                        TopMenuItemView(item: item)
                    }
                } label: {
                    TopMenuButton(title: menu.titleStr) {}
                        .help("Open menu: '\(menu.titleStr)'")
                }
                .buttonStyle(TopMenuButtonStyle())
            }
            
            Spacer() // Push Help menu to the right edge
            
                // Help menu rendered separately
            if let helpMenu = menuData.last {
                Menu {
                    ForEach(helpMenu.items) { item in
                        TopMenuItemView(item: item)
                    }
                } label: {
                    TopMenuButton(title: helpMenu.titleStr) {}
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
