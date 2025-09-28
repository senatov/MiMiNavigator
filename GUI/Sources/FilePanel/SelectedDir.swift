//
//  SelectedDir.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.05.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Combine
import Foundation

// MARK: - Encapsulates the selected file system entity and its associated panel side
class SelectedDir: ObservableObject {
    @Published var selectedFSEntity: CustomFile?
    let side: PanelSide

    // MARK: - Config keys
    private static let kLastFocusedPanel = "app.lastFocusedPanel"
    private static let kLeftLastPath     = "panel.left.lastPath"
    private static let kRightLastPath    = "panel.right.lastPath"

    // MARK: - Config helpers
    private static func parsePanelSide(_ raw: String) -> PanelSide? {
        switch raw.lowercased() {
        case "left": return .left
        case "right": return .right
        default: return nil
        }
    }

    /// Returns a stored start path for a given side if present and non-empty
    private static func resolveStartPath(for side: PanelSide) -> String? {
        let defaults = UserDefaults.standard
        let key = (side == .left) ? kLeftLastPath : kRightLastPath
        if let path = defaults.string(forKey: key), !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Validate path exists; if not, treat as absent
            if FileManager.default.fileExists(atPath: path) {
                return path
            } else {
                log.debug("Config start path not found on disk, ignoring: \(path)")
            }
        }
        return nil
    }

    /// Attempts to load the last focused panel side from config
    private static func loadSideFromConfig() -> PanelSide? {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: kLastFocusedPanel), let s = parsePanelSide(raw) {
            return s
        }
        return nil
    }

    // MARK: - Designated initializer
    init(side: PanelSide = .left, initialPath: String? = nil) {
        // Prefer side from config if available; otherwise use the passed-in value
        let restoredSide = SelectedDir.loadSideFromConfig() ?? side
        self.side = restoredSide

        // Determine start path: explicit parameter > config > default
        let configPath = SelectedDir.resolveStartPath(for: restoredSide)
        let startPath = initialPath ?? configPath ?? "/tmp"

        // Log what we restored
        if initialPath != nil {
            log.info("\(#function) side=\(restoredSide) (explicit path)")
        } else if configPath != nil {
            log.info("\(#function) side=\(restoredSide) (restored from config)")
        } else {
            log.info("\(#function) side=\(restoredSide) (using defaults)")
        }

        // Initialize selection with resolved path
        self.selectedFSEntity = CustomFile(path: startPath)

        // Extra debug
        log.debug("SelectedDir initialized with path: \(startPath)")
    }

    // MARK: - Convenience initializer
    convenience init() {
        let sideFromConfig = SelectedDir.loadSideFromConfig() ?? .left
        let pathFromConfig = SelectedDir.resolveStartPath(for: sideFromConfig)
        self.init(side: sideFromConfig, initialPath: pathFromConfig)
    }
}