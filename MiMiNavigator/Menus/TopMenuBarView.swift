//
//  TopMenuBarView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//  Description: SwiftUI component for rendering the top menu bar with dropdown menus and shortcuts.
//

import SwiftUI

struct TopMenuBarView: View {
    @Binding var isShowMenu: Bool  // Toggles menu visibility on/off
    @State private var isHovering = false
    @State private var showTooltip = false
    var toggleMenu: () -> Void  // Action to flip that menu on or off

    var body: some View {
        HStack(spacing: 8) {
                // 🍔 The legendary "Hamburger" button
            Button(action: toggleMenu) {
                Image(systemName: "line.horizontal.3")
                    .frame(width: 18, height: 18)
            }
            .help("External links live here!")
            .accessibilityLabel("Toggle menu visibility")
            .background(BlurView())
            .padding(.horizontal, 15)
            .padding(.vertical, 4)

                // 🚀 The main menu squad (excluding Help at the end)
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
                            .help("Some handy buttons for ya")
                            .onHover { hovering in
                                isHovering = hovering
                                if hovering {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if isHovering && !showTooltip {
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
                        PrettyTooltip(text: "Menu \(menu.title)")
                            .offset(x: 10, y: -34)
                            .transition(.opacity.combined(with: .scale))
                            .zIndex(1)
                    }
                }
                .buttonStyle(TopMenuButtonStyle())
            }

            Spacer()  // 🚧 Pushes "Help" waaaay over to the right side

                // 🆘 The mighty "Help" menu at the edge of the universe
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
                .padding(.trailing, 1)  // Little space to breathe from the right edge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .background(BlurView())  // Fancy blurred background for our top menu bar
    }

        // 🗃️ All the juicy menu items loaded here:
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
