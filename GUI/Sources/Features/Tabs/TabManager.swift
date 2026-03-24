    // TabManager.swift
    // MiMiNavigator
    //
    // Created by Claude on 14.02.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Manages tabs for a single panel — add, remove, select, persist

    import Foundation
    import FileModelKit

    // MARK: - Tab Manager
    /// Manages an ordered collection of tabs for one panel side.
    /// Guarantees at least one tab is always present.
    /// Observable for SwiftUI binding.
    @MainActor
    @Observable
    final class TabManager {

        // MARK: - Properties

        let panelSide: FavPanelSide
        private(set) var tabs: [TabItem] = []
        private(set) var activeTabID: UUID
        private(set) var activeTabIndex: Int

        // MARK: - Constants

        private enum Limits {
            static let maxTabs = 32
        }

        // MARK: - Init

        init(panelSide: FavPanelSide, initialURL: URL) {
            self.panelSide = panelSide
            let initialTab = TabItem.directory(url: initialURL)
            self.tabs = [initialTab]
            self.activeTabIndex = 0
            self.activeTabID = initialTab.id
            log.debug("[TabManager] init panel=\(panelSide) url='\(initialURL.path)'")
        }

        // MARK: - Active Tab

        /// Currently active tab
        var activeTab: TabItem {
            tabs[activeTabIndex]
        }

        // MARK: - Tab Selection

        /// Switch to a tab by ID
        func selectTab(_ tabID: UUID) {
            guard let index = tabs.firstIndex(where: { $0.id == tabID }) else {
                log.warning("[TabManager] selectTab: tab \(tabID) not found")
                return
            }
            log.debug("[TabManager] selectTab panel=\(panelSide) id=\(tabID)")
            activeTabIndex = index
            activeTabID = tabID
        }

        /// Switch to next tab (wraps around)
        func selectNextTab() {
            let currentIndex = activeTabIndex
            let nextIndex = (currentIndex + 1) % tabs.count
            activeTabIndex = nextIndex
            activeTabID = tabs[nextIndex].id
            log.debug("[TabManager] selectNextTab panel=\(panelSide) index=\(currentIndex)→\(nextIndex)")
        }

        /// Switch to previous tab (wraps around)
        func selectPreviousTab() {
            let currentIndex = activeTabIndex
            let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
            activeTabIndex = prevIndex
            activeTabID = tabs[prevIndex].id
            log.debug("[TabManager] selectPreviousTab panel=\(panelSide) index=\(currentIndex)→\(prevIndex)")
        }

        // MARK: - Add Tab

        /// Open a new tab for the given path, inserted after active tab
        @discardableResult
        func addTab(url: URL, archiveURL: URL? = nil) -> TabItem {
            guard tabs.count < Limits.maxTabs else {
                log.warning("[TabManager] addTab: maxTabs (\(Limits.maxTabs)) reached, ignoring")
                return activeTab
            }

            let newTab: TabItem
            if let archiveURL {
                newTab = TabItem.archive(extractedURL: url, archiveURL: archiveURL)
            } else {
                newTab = TabItem.directory(url: url)
            }

            // Insert after active tab
            let insertIndex = activeTabIndex + 1
            tabs.insert(newTab, at: insertIndex)
            activeTabIndex = insertIndex
            activeTabID = newTab.id

            log.info("[TabManager] addTab panel=\(panelSide) path='\(url.path)' index=\(insertIndex) total=\(tabs.count)")
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

            let closedURL = tabs[index].url
            let wasActive = (tabID == activeTabID)
            tabs.remove(at: index)

            // If closed tab was active, select adjacent tab
            if wasActive {
                let newIndex = min(index, tabs.count - 1)
                activeTabIndex = newIndex
                activeTabID = tabs[newIndex].id
                log.debug("[TabManager] closeTab: was active, selected index=\(newIndex)")
            }

            log.info("[TabManager] closeTab panel=\(panelSide) path='\(closedURL.path)' remaining=\(tabs.count)")
        }

        /// Close the currently active tab
        func closeActiveTab() {
            closeTab(activeTabID)
        }

        /// Close all tabs except the specified one
        func closeOtherTabs(keeping tabID: UUID) {
            guard tabs.contains(where: { $0.id == tabID }) else {
                log.warning("[TabManager] closeOtherTabs: tab \(tabID) not found")
                return
            }

            let closedCount = tabs.count - 1
            tabs.removeAll { $0.id != tabID }
            activeTabIndex = 0
            activeTabID = tabID

            log.info("[TabManager] closeOtherTabs panel=\(panelSide) closed=\(closedCount) remaining=1")
        }

        /// Close all tabs to the right of the specified tab
        func closeTabsToRight(of tabID: UUID) {
            guard let index = tabs.firstIndex(where: { $0.id == tabID }) else {
                log.warning("[TabManager] closeTabsToRight: tab \(tabID) not found")
                return
            }

            let removeCount = tabs.count - index - 1
            guard removeCount > 0 else {
                log.debug("[TabManager] closeTabsToRight: no tabs to the right")
                return
            }

            tabs.removeSubrange((index + 1)...)

            // If active tab was removed, switch to the rightmost remaining
            if let idx = tabs.firstIndex(where: { $0.id == activeTabID }) {
                activeTabIndex = idx
            } else {
                activeTabIndex = tabs.count - 1
                activeTabID = tabs.last!.id
            }

            log.info("[TabManager] closeTabsToRight panel=\(panelSide) closed=\(removeCount) remaining=\(tabs.count)")
        }

        /// Duplicate a tab (insert copy right after it)
        @discardableResult
        func duplicateTab(_ tabID: UUID) -> TabItem? {
            guard let index = tabs.firstIndex(where: { $0.id == tabID }) else {
                log.warning("[TabManager] duplicateTab: tab \(tabID) not found")
                return nil
            }

            guard tabs.count < Limits.maxTabs else {
                log.warning("[TabManager] duplicateTab: maxTabs (\(Limits.maxTabs)) reached")
                return nil
            }

            let original = tabs[index]
            let duplicate = TabItem(
                url: original.url,
                archiveURL: original.archiveURL
            )

            tabs.insert(duplicate, at: index + 1)
            activeTabIndex = index + 1
            activeTabID = duplicate.id

            log.info("[TabManager] duplicateTab panel=\(panelSide) original='\(original.displayName)' total=\(tabs.count)")
            return duplicate
        }

        // MARK: - Update Active Tab Path

        /// Update the path of the currently active tab (directory navigation)
        func updateActiveTabPath(_ newURL: URL) {
            tabs[activeTabIndex].url = newURL.standardizedFileURL
            tabs[activeTabIndex].archiveURL = nil
            log.debug("[TabManager] updateActiveTabPath panel=\(panelSide) → '\(newURL.path)'")
        }

        /// Mark active tab as inside an archive
        func updateActiveTabForArchive(extractedURL: URL, archiveURL: URL) {
            tabs[activeTabIndex].url = extractedURL.standardizedFileURL
            tabs[activeTabIndex].archiveURL = archiveURL
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

                // Validate paths — keep only tabs with accessible directories.
                // Resolve container symlinks (e.g. ~/Library/Containers/.../Data/Downloads → ~/Downloads)
                let validTabs: [TabItem] = decoded.compactMap { tab in
                    let realURL = tab.url.resolvingSymlinksInPath()
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: realURL.path, isDirectory: &isDir), isDir.boolValue else {
                        return nil
                    }
                    if realURL != tab.url {
                        log.debug("[TabManager] symlink resolved: \(tab.url.path) → \(realURL.path)")
                        var updated = tab
                        updated.url = realURL
                        return updated
                    }
                    return tab
                }

                guard !validTabs.isEmpty else {
                    log.warning("[TabManager] restoreTabs: no valid tabs after filtering, keeping current")
                    return
                }

                tabs = validTabs
                activeTabIndex = tabs.firstIndex(where: { $0.id == activeTabID }) ?? 0
                activeTabID = tabs[activeTabIndex].id

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
            if let index = tabs.firstIndex(where: { $0.id == uuid }) {
                activeTabIndex = index
                activeTabID = uuid
            }
            log.debug("[TabManager] restoreActiveTabID panel=\(panelSide) → \(uuid)")
        }
    }
