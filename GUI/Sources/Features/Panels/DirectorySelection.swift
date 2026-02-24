// DirectorySelection.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 09.05.25.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Encapsulates the selected file system entity and persistence

import Foundation
import FileModelKit

// MARK: - Directory Selection State
/// Observable class that encapsulates the selected file system entity
/// and provides persistence for panel state across app launches.
@Observable
class DirectorySelection {
    var selectedFSEntity: CustomFile?

    // MARK: - Config keys
    private enum Keys {
        static let lastFocusedPanel = "app.lastFocusedPanel"
        static let leftLastPath = "panel.left.lastPath"
        static let rightLastPath = "panel.right.lastPath"
    }

    // MARK: - Parse panel side from string
    private static func parsePanelSide(_ raw: String) -> PanelSide? {
        switch raw.lowercased() {
        case "left": return .left
        case "right": return .right
        default: return nil
        }
    }

    // MARK: - Resolve start path for panel
    /// Returns a stored start path for a given side if present and valid
    private static func resolveStartPath(for panelSide: PanelSide) -> String? {
        let defaults = UserDefaults.standard
        let key = (panelSide == .left) ? Keys.leftLastPath : Keys.rightLastPath
        
        if let path = defaults.string(forKey: key),
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Validate path exists
            if FileManager.default.fileExists(atPath: path) {
                return path
            } else {
                log.debug("Config start path not found on disk, ignoring: \(path)")
            }
        }
        return nil
    }

    // MARK: - Load side from config
    /// Attempts to load the last focused panel side from config
    private static func loadSideFromConfig() -> PanelSide? {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Keys.lastFocusedPanel),
           let side = parsePanelSide(raw) {
            return side
        }
        return nil
    }

    // MARK: - Designated initializer
    init(side: PanelSide = .left, initialPath: String? = nil) {
        // Prefer side from config if available; otherwise use passed-in value
        let restoredSide = DirectorySelection.loadSideFromConfig() ?? side
        
        // Determine start path: explicit param > config > default
        let configPath = DirectorySelection.resolveStartPath(for: restoredSide)
        let startPath = initialPath ?? configPath ?? "/tmp"

        // Log restoration source
        if initialPath != nil {
            log.info("DirectorySelection side=\(restoredSide) (explicit path)")
        } else if configPath != nil {
            log.info("DirectorySelection side=\(restoredSide) (restored from config)")
        } else {
            log.info("DirectorySelection side=\(restoredSide) (using defaults)")
        }

        self.selectedFSEntity = CustomFile(path: startPath)
        log.debug("DirectorySelection initialized with path: \(startPath)")
    }

    // MARK: - Convenience initializer
    convenience init() {
        let sideFromConfig = DirectorySelection.loadSideFromConfig() ?? .left
        let pathFromConfig = DirectorySelection.resolveStartPath(for: sideFromConfig)
        self.init(side: sideFromConfig, initialPath: pathFromConfig)
    }
}
