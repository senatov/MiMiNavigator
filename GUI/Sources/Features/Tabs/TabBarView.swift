// TabBarView.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Horizontal tab bar above breadcrumb navigation — shows all tabs for one panel

import SwiftUI

// MARK: - Tab Bar View
/// Horizontal scrollable tab bar displayed above the breadcrumb in each panel.
/// Shows all open tabs with the active tab highlighted.
/// Hidden when only one tab is present (clean single-tab experience).
struct TabBarView: View {

    @Environment(AppState.self) var appState
    let panelSide: PanelSide

    // MARK: - Computed

    private var tabManager: TabManager {
        appState.tabManager(for: panelSide)
    }

    // MARK: - Body

    var body: some View {
        let tabs = tabManager.tabs
        let activeID = tabManager.activeTabID
        let isOnlyTab = tabs.count <= 1

        // Hide tab bar when single tab (clean look)
        if tabs.count > 1 {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(tabs) { tab in
                            TabItemView(
                                tab: tab,
                                isActive: tab.id == activeID,
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
                    .padding(.leading, 6)
                    .padding(.top, 4)
                }
                .frame(height: 32)
                .background(tabBarBackground)
                .onChange(of: activeID) { _, newID in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Tab Bar Background

    private var tabBarBackground: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor).opacity(0.5)
            // Bottom separator — the "floor" of the tab bar
            VStack(spacing: 0) {
                Spacer()
                Color(nsColor: .separatorColor).opacity(0.45)
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: - Actions

    private func handleTabSelect(_ tab: TabItem) {
        let mgr = tabManager
        guard tab.id != mgr.activeTabID else { return }

        log.info("[TabBarView] selectTab panel=\(panelSide) tab='\(tab.displayName)'")
        mgr.selectTab(tab.id)

        // Sync panel path to the selected tab's path
        Task { @MainActor in
            appState.updatePath(tab.path, for: panelSide)
            if panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: tab.path)
                await appState.scanner.refreshFiles(currSide: .left)
                await appState.refreshLeftFiles()
            } else {
                await appState.scanner.setRightDirectory(pathStr: tab.path)
                await appState.scanner.refreshFiles(currSide: .right)
                await appState.refreshRightFiles()
            }
        }
    }

    private func handleTabClose(_ tab: TabItem) {
        let mgr = tabManager
        let wasActive = (tab.id == mgr.activeTabID)

        log.info("[TabBarView] closeTab panel=\(panelSide) tab='\(tab.displayName)' wasActive=\(wasActive)")
        mgr.closeTab(tab.id)

        // If closed tab was active, navigate to the new active tab
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

    // MARK: - Sync Helper

    /// Navigate the panel to the current active tab's path
    private func syncToActiveTab() {
        let newActive = tabManager.activeTab
        Task { @MainActor in
            appState.updatePath(newActive.path, for: panelSide)
            if panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: newActive.path)
                await appState.scanner.refreshFiles(currSide: .left)
                await appState.refreshLeftFiles()
            } else {
                await appState.scanner.setRightDirectory(pathStr: newActive.path)
                await appState.scanner.refreshFiles(currSide: .right)
                await appState.refreshRightFiles()
            }
        }
    }
}
