// TabBarView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Horizontal tab strip in the bottom panel status bar.

import FileModelKit
import SwiftUI

// MARK: - Tab Bar View
/// Horizontal tab strip displayed in the bottom panel status bar.
struct TabBarView: View {

    @Environment(AppState.self) var appState
    let panelSide: FavPanelSide

    // MARK: - Computed

    private var tabManager: TabManager {
        appState.tabManager(for: panelSide)
    }

    private var isPanelFocused: Bool {
        appState.focusedPanel == panelSide
    }

    // MARK: - Body

    var body: some View {
        let tabs = tabManager.tabs
        let activeID = tabManager.activeTabID
        let isOnlyTab = tabs.count <= 1
        ScrollViewReader { proxy in
            HStack(spacing: 2) {
                tabNavigationButton(systemName: "chevron.left", action: handleSelectPrevious)
                tabNavigationButton(systemName: "chevron.right", action: handleSelectNext)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tabs) { tab in
                            TabItemView(
                                tab: tab,
                                panelSide: panelSide,
                                isActive: tab.id == activeID,
                                isPanelFocused: isPanelFocused,
                                isOnlyTab: isOnlyTab,
                                tabCount: tabs.count,
                                onSelect: {
                                    handleTabSelect(tab)
                                },
                                onClose: {
                                    handleTabClose(tab)
                                },
                                onCloseOthers: {
                                    handleCloseOthers(keeping: tab)
                                },
                                onCloseToRight: {
                                    handleCloseToRight(of: tab)
                                },
                                onDuplicate: {
                                    handleDuplicate(tab)
                                }
                            )
                            .id(tab.id)
                        }
                    }
                }
                .frame(height: 31)
                addTabButton
            }
            .frame(height: 32)
            .onChange(of: activeID) { _, newID in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    // MARK: - Add Tab Button

    private var addTabButton: some View {
        Button(action: handleAddTab) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 20, height: 22)
        }
        .buttonStyle(TabStripControlButtonStyle(isEmphasized: true))
        .help("New Tab")
    }

    // MARK: - Navigation Button

    private func tabNavigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 18, height: 22)
        }
        .buttonStyle(TabStripControlButtonStyle(isEmphasized: false))
    }

    // MARK: - Actions

    private func handleTabSelect(_ tab: TabItem) {
        let mgr = tabManager
        appState.focusedPanel = panelSide
        guard tab.id != mgr.activeTabID else { return }
        log.info("[TabBarView] selectTab panel=\(panelSide) tab='\(tab.displayName)'")
        mgr.selectTab(tab.id)
        syncToActiveTab()
    }

    private func handleTabClose(_ tab: TabItem) {
        let mgr = tabManager
        let wasActive = (tab.id == mgr.activeTabID)
        log.info("[TabBarView] closeTab panel=\(panelSide) tab='\(tab.displayName)' wasActive=\(wasActive)")
        mgr.closeTab(tab.id)
        if wasActive {
            syncToActiveTab()
        }
    }

    private func handleCloseOthers(keeping tab: TabItem) {
        let mgr = tabManager
        log.info("[TabBarView] closeOthers panel=\(panelSide) keeping='\(tab.displayName)'")
        mgr.closeOtherTabs(keeping: tab.id)
        syncToActiveTab()
    }

    private func handleCloseToRight(of tab: TabItem) {
        let mgr = tabManager
        let activeWasRight = mgr.activeTabIndex > (mgr.tabs.firstIndex(where: { $0.id == tab.id }) ?? 0)
        log.info("[TabBarView] closeToRight panel=\(panelSide) of='\(tab.displayName)'")
        mgr.closeTabsToRight(of: tab.id)
        if activeWasRight {
            syncToActiveTab()
        }
    }

    private func handleDuplicate(_ tab: TabItem) {
        let mgr = tabManager
        log.info("[TabBarView] duplicate panel=\(panelSide) tab='\(tab.displayName)'")
        mgr.duplicateTab(tab.id)
        syncToActiveTab()
    }

    private func handleAddTab() {
        let mgr = tabManager
        appState.focusedPanel = panelSide
        let url = appState.url(for: panelSide)
        log.info("[TabBarView] addTab panel=\(panelSide) path='\(url.path)'")
        _ = mgr.addTab(url: url)
        syncToActiveTab()
    }

    private func handleSelectPrevious() {
        let mgr = tabManager
        appState.focusedPanel = panelSide
        mgr.selectPreviousTab()
        syncToActiveTab()
    }

    private func handleSelectNext() {
        let mgr = tabManager
        appState.focusedPanel = panelSide
        mgr.selectNextTab()
        syncToActiveTab()
    }

    // MARK: - Sync Helper

    /// Navigate the panel to the current active tab's path.
    private func syncToActiveTab() {
        let newActive = tabManager.activeTab
        Task { @MainActor in
            let url = newActive.url
            let target = url.isFileURL ? url.path : url.absoluteString
            await appState.navigateToDirectory(target, on: panelSide)
        }
    }
}

// MARK: - Tab Strip Control Button Style
private struct TabStripControlButtonStyle: ButtonStyle {
    let isEmphasized: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEmphasized ? Color.accentColor : Color(nsColor: .secondaryLabelColor))
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [Color.black.opacity(0.09), Color.white.opacity(0.12)]
                                : [Color.white.opacity(0.68), Color.primary.opacity(0.07)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.black.opacity(configuration.isPressed ? 0.25 : 0.16), lineWidth: 0.6)
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.12), radius: 1, y: configuration.isPressed ? 0 : 1)
            .offset(y: configuration.isPressed ? 0.5 : 0)
    }
}
