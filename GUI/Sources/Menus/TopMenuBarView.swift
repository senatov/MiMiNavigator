    //
    // TopMenuBarView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 16.10.24.
    // Description: SwiftUI component for rendering top menu barw/dropdown menus+shortcuts.
    //

import AppKit
import SwiftUI

struct TopMenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var favoritesTargetSide: PanelSide = .left
        // MARK: - Pixel helpers
    fileprivate var px: CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return 1.0 / scale
    }
        // MARK: -
    var body: some View {
        ZStack(alignment: .top) {
                // Glass bar background (liquid-glass, macOS 26.1 style)
            RoundedRectangle(cornerRadius: MenuBarMetrics.corner, style: .continuous)
                .fill(.ultraThinMaterial)
                // Decorative hairline ring (crisp, gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: MenuBarMetrics.corner, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.30),  // top highlight
                                    Color.blue.opacity(0.08),
                                    Color.black.opacity(0.12),  // bottom subtle shadow
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: px
                        )
                )
                // Soft top glow
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.blue.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: MenuBarMetrics.height * 0.55)
                }
                // Crisp bottom hairline
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.40),  // upper edge highlight
                                    Color.white.opacity(0.18),
                                    Color.black.opacity(0.20)   // lower subtle shadow
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: px)
                        .padding(.horizontal, 0.5)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: MenuBarMetrics.corner, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: MenuBarMetrics.corner, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 2)
                .shadow(color: Color.blue.opacity(0.06), radius: 18, x: 0, y: 10)
            
                // Menu row
            HStack(spacing: 6) {
                ForEach(menuData.dropLast()) { menu in
                    menuView(for: menu)
                }
                Spacer(minLength: 12)
                if let helpMenu = menuData.last {
                    Menu {
                        ForEach(helpMenu.items) { item in
                            TopMenuItemView(item: item)
                        }
                    } label: {
                        Text(helpMenu.title)
                            .font(.system(size: 13, weight: .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(minHeight: 26, alignment: .center)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .help("Open menu: '\(helpMenu.title)'")
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(TopMenuButtonStyle())
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
    
        // MARK: -
    private func menuView(for menu: MenuCategory) -> some View {
            // Explicit return for clarity
        return Menu(menu.title) {
            ForEach(menu.items) { item in
                TopMenuItemView(item: item)
            }
        }
        .help("Open menu: \(menu.title)")
        .menuStyle(.borderlessButton)  // ensure flat dropdown look per Figma/macOS
        .controlSize(.small)
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
