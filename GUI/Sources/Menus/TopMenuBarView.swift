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
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.82)
                .overlay(alignment: .bottom) {
                    Color.primary.opacity(0.10).frame(height: 1)
                }
            HStack(spacing: 6) {
                finderSidebarButton
                ForEach(menuData.dropLast()) { menu in
                    TopMenuPopoverButton(menu: menu, tint: menuTint(for: menu))
                }
                RemoteConnectionsDropdown(appState: appState)
                    .padding(.leading, 12)
                VolumesDropdown(appState: appState)
                Spacer(minLength: 12)
                if let helpMenu = menuData.last {
                    TopMenuPopoverButton(menu: helpMenu, tint: menuTint(for: helpMenu))
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
        .onAppear {
            log.debug("TopMenuBarView appeared")
            if appState.showFavTreePopup {
                favoritesTargetSide = appState.focusedPanel
            }
        }
        .onChange(of: appState.showFavTreePopup) { _, newValue in
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
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.blue)
                .frame(width: 22, height: 22)
        }
        .help(isFinderSidebarVisible ? "Hide Finder sidebar" : "Show Finder sidebar")
        .buttonStyle(TopMenuButtonStyle(isSelected: isFinderSidebarVisible))
        .keyboardFocusable()
    }

    // MARK: - Menu Tint
    private func menuTint(for menu: MenuCategory) -> Color {
        switch menu.title {
            case "Files": return .blue
            case "Mark": return .green
            case "Commands": return .indigo
            case "Net": return .teal
            case "Show": return .orange
            case "Start": return .purple
            case "Help": return .pink
            default: return .accentColor
        }
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
            startMenuCategory,
            helpMenuCategory,
        ]
    }
}
