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
        return ZStack(alignment: .top) {
                // Glass-like background bar with a thin bottom separator (Figma/macOS 26)
            Rectangle()
                .fill(.regularMaterial)
                .frame(height: 36)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(.separator)
                }
            
                // Existing menu row kept intact (structure/logic unchanged)
            HStack(spacing: 6) {
                ForEach(menuData.dropLast()) { menu in
                    menuView(for: menu)
                }
                Spacer(minLength: 12) // keep Help menu pushed to the right with consistent gap
                
                if let helpMenu = menuData.last {
                    Menu {
                        ForEach(helpMenu.items) { item in
                            TopMenuItemView(item: item)
                        }
                    } label: {
                        Text(helpMenu.title)
                            .font(.system(size: 13, weight: .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .frame(minHeight: 26, alignment: .center)
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                            .help("Open menu: '\(helpMenu.title)'")
                    }
                    .menuStyle(.borderlessButton)      // flat, menu-like appearance
                    .buttonStyle(TopMenuButtonStyle()) // keep your custom text-button look
                    .padding(.trailing, 1)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36, alignment: .center)
            .accessibilityElement(children: .contain)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.clear) // no opaque backgrounds behind the bar
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
        .menuStyle(.borderlessButton)     // ensure flat dropdown look per Figma/macOS
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
