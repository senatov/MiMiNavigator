// TabManager.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages tabs for a single panel — add, remove, select, persist

import Foundation

// MARK: - Tab Manager
/// Manages an ordered collection of tabs for one panel side.
/// Guarantees at least one tab is always present.
/// Observable for SwiftUI binding.
@MainActor
@Observable
final class TabManager {

    // MARK: - Properties

    let panelSide: PanelSide
    private(set) var tabs: [TabItem] = []
    private(set) var activeTabID: UUID

    // MARK: - Constants

    private enum Limits {
        static let maxTabs = 32
    }

    // MARK: - Init

    init(panelSide: PanelSide, initialPath: String) {
        self.panelSide = panelSide
        let initialTab = TabItem.directory(path: initialPath)
        self.tabs = [initialTab]
        self.activeTabID = initialTab.id
        log.debug("[TabManager] init panel=\(panelSide) path='\(initialPath)'")
    }

    // MARK: - Active Tab

    /// Currently active tab
    var activeTab: TabItem {
        guard let tab = tabs.first(where: { $0.id == activeTabID }) else {
            log.error("[TabManager] activeTab not found, returning first tab")
            return tabs[0]
        }
        return tab
    }

    /// Index of the active tab
    var activeTabIndex: Int {
        tabs.firstIndex(where: { $0.id == activeTabID }) ?? 0
    }

    // MARK: - Tab Selection

    /// Switch to a tab by ID
    func selectTab(_ tabID: UUID) {
        guard tabs.contains(where: { $0.id == tabID }) else {
            log.warning("[TabManager] selectTab: tab \(tabID) not found")
            return
        }
        log.debug("[TabManager] selectTab panel=\(panelSide) id=\(tabID)")
        activeTabID = tabID
    }

    /// Switch to next tab (wraps around)
    func selectNextTab() {
        let currentIndex = activeTabIndex
        let nextIndex = (currentIndex + 1) % tabs.count
        activeTabID = tabs[nextIndex].id
        log.debug("[TabManager] selectNextTab panel=\(panelSide) index=\(currentIndex)→\(nextIndex)")
    }

    /// Switch to previous tab (wraps around)
    func selectPreviousTab() {
        let currentIndex = activeTabIndex
        let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
        activeTabID = tabs[prevIndex].id
        log.debug("[TabManager] selectPreviousTab panel=\(panelSide) index=\(currentIndex)→\(prevIndex)")
    }

    // MARK: - Add Tab

    /// Open a new tab for the given path, inserted after active tab
    @discardableResult
    func addTab(path: String, isArchive: Bool = false, archiveURL: URL? = nil) -> TabItem {
        guard tabs.count < Limits.maxTabs else {
            log.warning("[TabManager] addTab: maxTabs (\(Limits.maxTabs)) reached, ignoring")
            return activeTab
        }

        let newTab: TabItem
        if isArchive, let archiveURL {
            newTab = TabItem.archive(extractedPath: path, archiveURL: archiveURL)
        } else {
            newTab = TabItem.directory(path: path)
        }

        // Insert after active tab
        let insertIndex = activeTabIndex + 1
        tabs.insert(newTab, at: insertIndex)
        activeTabID = newTab.id

        log.info("[TabManager] addTab panel=\(panelSide) path='\(path)' index=\(insertIndex) total=\(tabs.count)")
        return newTab
    }

    // MARK: - Close Tab

    /// Close a tab by ID. Last remaining tab cannot be closed.
    func closeTab(_ tabID: UUID) {
        guard tabs.count > 1 else {
            log.debug("[TabManager] closeTab: only one tab, ignoring")
            return
        }

        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else {
            log.warning("[TabManager] closeTab: tab \(tabID) not found")
            return
        }

        let closedPath = tabs[index].path
        let wasActive = (tabID == activeTabID)
        tabs.remove(at: index)

        // If closed tab was active, select adjacent tab
        if wasActive {
            let newIndex = min(index, tabs.count - 1)
            activeTabID = tabs[newIndex].id
            log.debug("[TabManager] closeTab: was active, selected index=\(newIndex)")
        }

        log.info("[TabManager] closeTab panel=\(panelSide) path='\(closedPath)' remaining=\(tabs.count)")
    }

    /// Close the currently active tab
    func closeActiveTab() {
        closeTab(activeTabID)
    }

    // MARK: - Update Active Tab Path

    /// Update the path of the currently active tab (directory navigation)
    func updateActiveTabPath(_ newPath: String) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else {
            log.error("[TabManager] updateActiveTabPath: active tab not found")
            return
        }
        tabs[index].path = newPath
        tabs[index].isArchive = false
        tabs[index].archiveURL = nil
        log.debug("[TabManager] updateActiveTabPath panel=\(panelSide) → '\(newPath)'")
    }

    /// Mark active tab as inside an archive
    func updateActiveTabForArchive(extractedPath: String, archiveURL: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else {
            log.error("[TabManager] updateActiveTabForArchive: active tab not found")
            return
        }
        tabs[index].path = extractedPath
        tabs[index].isArchive = true
        tabs[index].archiveURL = archiveURL
        log.debug("[TabManager] updateActiveTabForArchive panel=\(panelSide) archive='\(archiveURL.lastPathComponent)'")
    }

    // MARK: - Persistence

    /// Encode tabs to Data for UserDefaults storage
    func encodedTabs() -> Data? {
        do {
            let data = try JSONEncoder().encode(tabs)
            log.debug("[TabManager] encodedTabs panel=\(panelSide) count=\(tabs.count)")
            return data
        } catch {
            log.error("[TabManager] encodedTabs FAILED: \(error.localizedDescription)")
            return nil
        }
    }

    /// Restore tabs from Data (e.g. from UserDefaults)
    func restoreTabs(from data: Data) {
        do {
            let decoded = try JSONDecoder().decode([TabItem].self, from: data)
            guard !decoded.isEmpty else {
                log.warning("[TabManager] restoreTabs: decoded empty array, keeping current")
                return
            }

            // Validate paths — keep only tabs with accessible directories
            let validTabs = decoded.filter { tab in
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: tab.path, isDirectory: &isDir) && isDir.boolValue
            }

            guard !validTabs.isEmpty else {
                log.warning("[TabManager] restoreTabs: no valid tabs after filtering, keeping current")
                return
            }

            tabs = validTabs
            // Restore active tab or fall back to first
            if !tabs.contains(where: { $0.id == activeTabID }) {
                activeTabID = tabs[0].id
            }

            log.info("[TabManager] restoreTabs panel=\(panelSide) restored=\(validTabs.count)/\(decoded.count)")
        } catch {
            log.error("[TabManager] restoreTabs FAILED: \(error.localizedDescription)")
        }
    }

    /// Encode the active tab ID for persistence
    var activeTabIDString: String {
        activeTabID.uuidString
    }

    /// Restore active tab ID from string
    func restoreActiveTabID(from string: String) {
        guard let uuid = UUID(uuidString: string),
              tabs.contains(where: { $0.id == uuid }) else {
            log.debug("[TabManager] restoreActiveTabID: invalid or missing UUID, keeping current")
            return
        }
        activeTabID = uuid
        log.debug("[TabManager] restoreActiveTabID panel=\(panelSide) → \(uuid)")
    }
}
