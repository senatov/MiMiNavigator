    // StatePersistence.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 27.01.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Save and restore app state to/from UserDefaults

    import Foundation
    import FileModelKit

    // MARK: - State Persistence
    /// Handles saving and restoring application state
    @MainActor
    enum StatePersistence {

        private static let stateFileURL: URL = {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dir = home.appendingPathComponent(".mimi", isDirectory: true)
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir.appendingPathComponent("state.json")
        }()

        private struct PersistentState: Codable {
            var leftPath: String
            var rightPath: String
            var focusedPanel: String
            var selectedLeftFile: String?
            var selectedRightFile: String?
            var leftTabs: Data?
            var rightTabs: Data?
            var leftActiveTabID: String?
            var rightActiveTabID: String?
            var sortKey: String
            var sortAscending: Bool
        }

        // MARK: - Save State

        /// Save current app state before exit
        static func saveBeforeExit(from state: AppState) {
            log.debug("[StatePersistence] saveBeforeExit")

            let snapshot = PersistentState(
                leftPath: state.leftPath,
                rightPath: state.rightPath,
                focusedPanel: state.focusedPanel == .left ? "left" : "right",
                selectedLeftFile: state.selectedLeftFile?.urlValue.path,
                selectedRightFile: state.selectedRightFile?.urlValue.path,
                leftTabs: state.leftTabManager.encodedTabs(),
                rightTabs: state.rightTabManager.encodedTabs(),
                leftActiveTabID: state.leftTabManager.activeTabIDString,
                rightActiveTabID: state.rightTabManager.activeTabIDString,
                sortKey: state.sortKey.rawValue,
                sortAscending: state.bSortAscending
            )

            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: stateFileURL, options: .atomic)
                log.info("[StatePersistence] state saved to ~/.mimi/state.json")
            } catch {
                log.error("[StatePersistence] failed to save state: \(error.localizedDescription)")
            }
        }

        // MARK: - Load Initial Paths

        /// Get initial URLs for panels (from UserDefaults or defaults).
        static func loadInitialPaths() -> (left: URL, right: URL) {
            let fm = FileManager.default
            let defaultLeft = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory())
            let defaultRight = fm.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: "/Users")

            guard let data = try? Data(contentsOf: stateFileURL),
                  let decoded = try? JSONDecoder().decode(PersistentState.self, from: data) else {
                return (defaultLeft, defaultRight)
            }

            let leftURL = validDirectoryURL(decoded.leftPath, fallback: defaultLeft)
            let rightURL = validDirectoryURL(decoded.rightPath, fallback: defaultRight)
            log.debug("[StatePersistence] loaded paths L=\(leftURL.path) R=\(rightURL.path)")
            return (leftURL, rightURL)
        }

        /// Returns URL for `path` if it points to an existing, accessible directory; otherwise `fallback`.
        private static func validDirectoryURL(_ path: String?, fallback: URL) -> URL {
            guard let path, !path.isEmpty else { return fallback }
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                log.warning("[StatePersistence] saved path missing/not dir: \(url.path) → fallback \(fallback.path)")
                return fallback
            }
            if url.path.contains("/DerivedData/") || url.path.contains(".xcarchive") {
                log.warning("[StatePersistence] ephemeral path: \(url.path) → fallback \(fallback.path)")
                return fallback
            }
            return url
        }

        /// Get initial focused panel
        static func loadInitialFocus() -> PanelSide {
            guard let data = try? Data(contentsOf: stateFileURL),
                  let decoded = try? JSONDecoder().decode(PersistentState.self, from: data),
                  decoded.focusedPanel == "right" else {
                return .left
            }
            return .right
        }

        // MARK: - Restore Tabs

        static func restoreTabs(into state: AppState) {
            guard let data = try? Data(contentsOf: stateFileURL),
                  let decoded = try? JSONDecoder().decode(PersistentState.self, from: data) else {
                return
            }

            if let leftData = decoded.leftTabs {
                state.leftTabManager.restoreTabs(from: leftData)
                if let activeID = decoded.leftActiveTabID {
                    state.leftTabManager.restoreActiveTabID(from: activeID)
                }
            }

            if let rightData = decoded.rightTabs {
                state.rightTabManager.restoreTabs(from: rightData)
                if let activeID = decoded.rightActiveTabID {
                    state.rightTabManager.restoreActiveTabID(from: activeID)
                }
            }

            log.info("[StatePersistence] tabs restored L=\(state.leftTabManager.tabs.count) R=\(state.rightTabManager.tabs.count)")
        }

        // MARK: - Restore Sorting

        static func restoreSorting(into state: AppState) {
            guard let data = try? Data(contentsOf: stateFileURL),
                  let decoded = try? JSONDecoder().decode(PersistentState.self, from: data) else {
                return
            }

            if let sortKey = SortKeysEnum(rawValue: decoded.sortKey) {
                state.sortKey = sortKey
            }
            state.bSortAscending = decoded.sortAscending

            log.debug("[StatePersistence] sorting restored: key=\(state.sortKey.rawValue) asc=\(state.bSortAscending)")
        }
    }
