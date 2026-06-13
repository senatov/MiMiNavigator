//
// TopMenuBarView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
// Description: SwiftUI component for rendering top menu bar with dropdown menus and shortcuts.
//

import FileModelKit
import SwiftUI

struct TopMenuBarView: View {
    @Environment(AppState.self) var appState
    @Binding var isFinderSidebarVisible: Bool
    @State private var favoritesTargetSide: FavPanelSide = .left

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            DuoPanelToolbarBackground(cornerRadius: MenuBarMetrics.corner)
            HStack(spacing: 6) {
                finderSidebarButton
                ForEach(menuData.dropLast()) { menu in
                    menuView(for: menu)
                }
                RemoteConnectionsDropdown(appState: appState)
                    .padding(.leading, 16)
                Spacer(minLength: 12)
                if let helpMenu = menuData.last {
                    menuView(for: helpMenu)
                        .padding(.trailing, 1)
                }
            }
            .padding(.horizontal, MenuBarMetrics.horizontalPadding)
            .frame(height: MenuBarMetrics.height, alignment: .center)
            .controlSize(.small)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Top menu bar")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.clear)
        .onAppear {
            log.debug("TopMenuBarView appeared")
            if appState.showFavTreePopup {
                favoritesTargetSide = appState.focusedPanel
            }
        }
        .onChange(of: appState.showFavTreePopup) { oldValue, newValue in
            if newValue {
                favoritesTargetSide = appState.focusedPanel
            }
        }
    }
    
        // MARK: - Finder Sidebar Toggle
    private var finderSidebarButton: some View {
        Button {
            isFinderSidebarVisible.toggle()
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14))
                .frame(width: 22, height: 22)
        }
        .help(isFinderSidebarVisible ? "Hide Finder sidebar" : "Show Finder sidebar")
        .buttonStyle(TopMenuButtonStyle())
        .focusable(false)
    }

        // MARK: -
    private func menuView(for menu: MenuCategory) -> some View {
        return Menu {
            ForEach(menu.items) { item in
                Button(action: item.action) {
                    Label {
                        if let shortcut = item.shortcut {
                            Text("\(item.title)  \(shortcut)")
                        } else {
                            Text(item.title)
                        }
                    } icon: {
                        if let icon = item.icon {
                            Image(systemName: icon)
                        }
                    }
                }
            }
        } label: {
            Label {
                Text(menu.title)
                    .font(.subheadline)
            } icon: {
                if let icon = menu.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
            }
        }
        .help("Open menu: \(menu.title)")
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .buttonStyle(TopMenuButtonStyle())
        .focusable(false)
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
