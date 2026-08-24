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
                    .padding(.leading, 12)
                VolumesDropdown(appState: appState)
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
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.blue)
                .frame(width: 22, height: 22)
        }
        .help(isFinderSidebarVisible ? "Hide Finder sidebar" : "Show Finder sidebar")
        .buttonStyle(TopMenuButtonStyle(isSelected: isFinderSidebarVisible))
        .keyboardFocusable()
    }

        // MARK: -
    private func menuView(for menu: MenuCategory) -> some View {
        return Menu {
            ForEach(menu.items) { item in
                Button(action: item.action) {
                    TopSubmenuLabel(
                        title: item.title,
                        shortcut: item.shortcut,
                        systemImage: item.icon,
                        tint: submenuTint(for: item)
                    )
                }
            }
        } label: {
            Label {
                Text(menu.title)
                    .font(.system(size: 14, weight: .light))
            } icon: {
                if let icon = menu.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(menuTint(for: menu))
                }
            }
        }
        .help("Open menu: \(menu.title)")
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .buttonStyle(TopMenuButtonStyle())
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

    // MARK: - Submenu Tint
    private func submenuTint(for item: MenuItem) -> Color {
        let title = item.title.lowercased()
        if title.contains("quit") || title.contains("delete") || title.contains("remove") { return .red }
        if title.contains("mark") || title.contains("select") || title.contains("start") { return .green }
        if title.contains("network") || title.contains("server") || title.contains("connect") { return .teal }
        if title.contains("help") || title.contains("about") { return .purple }
        if title.contains("settings") || title.contains("configuration") { return .orange }
        return .blue
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

// MARK: - Top Submenu Label
private struct TopSubmenuLabel: View {
    let title: String
    let shortcut: String?
    let systemImage: String?
    let tint: Color

    // MARK: - Body
    var body: some View {
        HStack(spacing: 7) {
            submenuIcon
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.72))
                .frame(width: 1, height: 15)
            Text(title)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 18)
            if let shortcut, !shortcut.isEmpty {
                Text(shortcut)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color(nsColor: .systemBlue))
                    .fixedSize()
            }
        }
        .frame(minWidth: 230, alignment: .leading)
    }

    // MARK: - Icon
    @ViewBuilder
    private var submenuIcon: some View {
        if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .light))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
                .frame(width: 17, height: 17)
        } else {
            Color.clear
                .frame(width: 17, height: 17)
        }
    }
}
