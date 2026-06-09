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
        if isOnlyTab {
            EmptyView()
        } else {
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
                    .frame(height: 28)
                    addTabButton
                }
                .frame(height: 29)
                .onChange(of: activeID) { _, newID in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Add Tab Button

    private var addTabButton: some View {
        Button(action: handleAddTab) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 22, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(nsColor: .darkGray))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.55))
                .frame(width: 1)
        }
        .help("New Tab")
    }

    // MARK: - Navigation Button

    private func tabNavigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
    }

    // MARK: - Actions

    private func handleTabSelect(_ tab: TabItem) {
        let mgr = tabManager
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
        let url = appState.url(for: panelSide)
        log.info("[TabBarView] addTab panel=\(panelSide) path='\(url.path)'")
        _ = mgr.addTab(url: url)
        syncToActiveTab()
    }

    private func handleSelectPrevious() {
        let mgr = tabManager
        mgr.selectPreviousTab()
        syncToActiveTab()
    }

    private func handleSelectNext() {
        let mgr = tabManager
        mgr.selectNextTab()
        syncToActiveTab()
    }

    // MARK: - Sync Helper

    /// Navigate the panel to the current active tab's path.
    private func syncToActiveTab() {
        let newActive = tabManager.activeTab
        Task { @MainActor in
            let url = newActive.url
            appState.updatePath(url, for: panelSide)
            if panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: url.path)
                await appState.scanner.refreshFiles(currSide: .left)
                await appState.refreshLeftFiles()
            } else {
                await appState.scanner.setRightDirectory(pathStr: url.path)
                await appState.scanner.refreshFiles(currSide: .right)
                await appState.refreshRightFiles()
            }
        }
    }
}
