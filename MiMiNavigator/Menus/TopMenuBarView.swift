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
            // Main menu items (excluding the final Help menu)
            ForEach(menuData.dropLast()) { menu in
                Menu {
                    ForEach(menu.items) { item in
                        TopMenuItemView(item: item)
                    }
                } label: {
                    Text(menu.title)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .font(.system(size: NSFont.systemFontSize, weight: .regular))
                        .foregroundColor(Color.primary)
                        .frame(height: 22)
                        .help("Open menu: '\(menu.title)'")
                }
                .buttonStyle(TopMenuButtonStyle())
            }
            Spacer()  // Pushes the Help menu to the far right
            // The mighty "Help" menu at the edge of the universe
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
                .padding(.trailing, 1)  // Adds a small spacing from the right edge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(BlurView().clipShape(RoundedRectangle(cornerRadius: 7)))  // Blurred background for the top menu bar
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
