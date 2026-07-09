// StatePersistence.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Save and restore app state to/from ~/.mimi/state.json

import AppKit
import Foundation
import FileModelKit

// MARK: - State Persistence
/// Handles saving and restoring application state
@MainActor
enum StatePersistence {

    /// cached window frame — updated on resize/move, used at exit
    static var lastKnownWindowFrame: NSRect?

    /// start observing window resize/move to keep frame cache fresh
    static func startTrackingWindowFrame() {
        Task { @MainActor in
            for await note in NotificationCenter.default.notifications(named: NSWindow.didEndLiveResizeNotification) {
                guard let win = note.object as? NSWindow, !(win is NSPanel) else { continue }
                lastKnownWindowFrame = win.frame
            }
        }
        Task { @MainActor in
            for await note in NotificationCenter.default.notifications(named: NSWindow.didMoveNotification) {
                guard let win = note.object as? NSWindow, !(win is NSPanel) else { continue }
                lastKnownWindowFrame = win.frame
            }
        }
        log.debug("[StatePersistence] window frame tracking started")
    }

    private static let stateDirectoryURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
    }()

    private static let stateFileURL: URL = {
        stateDirectoryURL.appendingPathComponent("state.json")
    }()

    private static func ensureStateStorageExists() {
        do {
            try FileManager.default.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true)
        } catch {
            log.error("[StatePersistence] failed to create state directory: \(error.localizedDescription)")
        }
    }

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
        var windowFrameX: Double?
        var windowFrameY: Double?
        var windowFrameW: Double?
        var windowFrameH: Double?
    }

// MARK: - Default State

private static func defaultPersistentState() -> PersistentState {
    PersistentState(
        leftPath: "",
        rightPath: "",
        focusedPanel: "left",
        selectedLeftFile: nil,
        selectedRightFile: nil,
        leftTabs: nil,
        rightTabs: nil,
        leftActiveTabID: nil,
        rightActiveTabID: nil,
        sortKey: SortKeysEnum.name.rawValue,
        sortAscending: true,
        windowFrameX: nil,
        windowFrameY: nil,
        windowFrameW: nil,
        windowFrameH: nil
    )
}

private static func writeStateToDisk(_ snapshot: PersistentState) {
    ensureStateStorageExists()
    do {
        let encoder = JSONEncoder()
        try SafeJSONStorage.writeCodable(snapshot, to: stateFileURL, label: "state.json", encoder: encoder)
    } catch {
        log.error("[StatePersistence] failed to write state: \(error.localizedDescription)")
    }
}

private static func ensureStateFileExists() {
    ensureStateStorageExists()
    guard !FileManager.default.fileExists(atPath: stateFileURL.path) else { return }
    writeStateToDisk(defaultPersistentState())
    log.info("[StatePersistence] created default ~/.mimi/state.json")
}

private static func loadPersistentState() -> PersistentState? {
    ensureStateFileExists()

    do {
        return try SafeJSONStorage.loadCodable(from: stateFileURL, as: PersistentState.self, label: "state.json")
    } catch {
        log.error("[StatePersistence] failed to load state: \(error.localizedDescription)")
        let snapshot = defaultPersistentState()
        writeStateToDisk(snapshot)
        log.info("[StatePersistence] reset ~/.mimi/state.json to defaults")
        return snapshot
    }
}

    // MARK: - Save State

    /// Save current app state before exit
    static func saveBeforeExit(from state: AppState) {
        ensureStateFileExists()
        log.debug("[StatePersistence] saveBeforeExit")
        let previous = loadPersistentState()
        let leftIsRestorable = isRestorablePanelPath(state.leftPath)
        let rightIsRestorable = isRestorablePanelPath(state.rightPath)
        let leftTabs = leftIsRestorable ? state.leftTabManager.encodedTabs() : previous?.leftTabs
        let rightTabs = rightIsRestorable ? state.rightTabManager.encodedTabs() : previous?.rightTabs
        let leftActiveTabID = leftIsRestorable ? state.leftTabManager.activeTabIDString : previous?.leftActiveTabID
        let rightActiveTabID = rightIsRestorable ? state.rightTabManager.activeTabIDString : previous?.rightActiveTabID
        // use cached frame — live window may already be closing
        let mainFrame = lastKnownWindowFrame
            ?? NSApp.windows.first(where: { !($0 is NSPanel) && $0.isVisible })?.frame
        let snapshot = PersistentState(
            leftPath: leftIsRestorable ? state.leftPath : previous?.leftPath ?? "",
            rightPath: rightIsRestorable ? state.rightPath : previous?.rightPath ?? "",
            focusedPanel: state.focusedPanel == .left ? "left" : "right",
            selectedLeftFile: leftIsRestorable ? state.selectedLeftFile?.urlValue.path : previous?.selectedLeftFile,
            selectedRightFile: rightIsRestorable ? state.selectedRightFile?.urlValue.path : previous?.selectedRightFile,
            leftTabs: leftTabs,
            rightTabs: rightTabs,
            leftActiveTabID: leftActiveTabID,
            rightActiveTabID: rightActiveTabID,
            sortKey: state.sortKey.rawValue,
            sortAscending: state.bSortAscending,
            windowFrameX: mainFrame.map { Double($0.origin.x) },
            windowFrameY: mainFrame.map { Double($0.origin.y) },
            windowFrameW: mainFrame.map { Double($0.size.width) },
            windowFrameH: mainFrame.map { Double($0.size.height) }
        )

        writeStateToDisk(snapshot)
        if !leftIsRestorable || !rightIsRestorable {
            log.warning("[StatePersistence] skipped transient panel path(s) on save: L=\(state.leftPath) R=\(state.rightPath)")
        }
        log.info("[StatePersistence] state saved to ~/.mimi/state.json")
    }

    // MARK: - Load Initial Paths

    /// Get initial URLs for panels (from UserDefaults or defaults).
    static func loadInitialPaths() -> (left: URL, right: URL) {
        ensureStateFileExists()
        let fm = FileManager.default
        let defaultLeft = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let defaultRight = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "/Users")

        guard let decoded = loadPersistentState() else {
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
        guard isRestorablePanelPath(path) else {
            log.warning("[StatePersistence] transient saved path: \(path) → fallback \(fallback.path)")
            return fallback
        }
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

    // MARK: - Restorable Panel Paths

    static func isRestorablePanelPath(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        if path.contains("/DerivedData/") || path.contains(".xcarchive") { return false }
        if isAppDistributionVolumePath(path) { return false }
        guard let volumePath = currentAppVolumePath() else { return true }
        return !PathUtils.areEqual(path, volumePath) && !path.hasPrefix(volumePath + "/")
    }

    private static func isAppDistributionVolumePath(_ path: String) -> Bool {
        guard path.hasPrefix("/Volumes/") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2, parts[0] == "Volumes" else { return false }
        return appDistributionVolumeNames().contains(String(parts[1]))
    }

    private static func appDistributionVolumeNames() -> Set<String> {
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return Set(["MiMiNavigator", bundleName, displayName].compactMap { $0 })
    }

    private static func currentAppVolumePath() -> String? {
        let bundlePath = Bundle.main.bundleURL.standardizedFileURL.path
        guard bundlePath.hasPrefix("/Volumes/") else { return nil }
        let parts = bundlePath.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2, parts[0] == "Volumes" else { return nil }
        return "/Volumes/\(parts[1])"
    }

    /// Get initial focused panel
    static func loadInitialFocus() -> FavPanelSide {
        ensureStateFileExists()
        guard let decoded = loadPersistentState(), decoded.focusedPanel == "right" else {
            return .left
        }
        return .right
    }

    // MARK: - Restore Window Frame

    /// Restore main window frame from state.json
    static func restoreWindowFrame() -> NSRect? {
        ensureStateFileExists()
        guard let decoded = loadPersistentState(),
              let x = decoded.windowFrameX,
              let y = decoded.windowFrameY,
              let w = decoded.windowFrameW,
              let h = decoded.windowFrameH,
              w > 100, h > 100 else {
            return nil
        }
        let frame = NSRect(x: x, y: y, width: w, height: h)
        // Sanity: frame must overlap at least one screen
        let overlaps = NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
        guard overlaps else {
            log.warning("[StatePersistence] saved frame off-screen: \(frame) — ignoring")
            return nil
        }
        log.debug("[StatePersistence] restored window frame: \(Int(w))x\(Int(h)) at (\(Int(x)),\(Int(y)))")
        return frame
    }

    // MARK: - Restore Tabs

    static func restoreTabs(into state: AppState) {
        ensureStateFileExists()
        guard let decoded = loadPersistentState() else {
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
        ensureStateFileExists()
        guard let decoded = loadPersistentState() else {
            return
        }

        if let sortKey = SortKeysEnum(rawValue: decoded.sortKey) {
            state.sortKey = sortKey
        }
        state.bSortAscending = decoded.sortAscending

        log.debug("[StatePersistence] sorting restored: key=\(state.sortKey.rawValue) asc=\(state.bSortAscending)")
    }
}
