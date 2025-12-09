//
// SelectedDir.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.05.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

// MARK: - Encapsulates the selected file system entity and its associated panel side
@Observable
class SelectedDir {
    var selectedFSEntity: CustomFile?

    // MARK: - Config keys
    private static let kLastFocusedPanel = "app.lastFocusedPanel"
    private static let kLeftLastPath = "panel.left.lastPath"
    private static let kRightLastPath = "panel.right.lastPath"

    // MARK: - Config helpers
    private static func parsePanelSide(_ raw: String) -> PanelSide? {
        switch raw.lowercased() {
            case "left": return .left
            case "right": return .right
            default: return nil
        }
    }

    // / Returns a stored start path for a given side if present+non-empty
    private static func resolveStartPath(for panelSide: PanelSide) -> String? {
        let defaults = UserDefaults.standard
        let key = (panelSide == .left) ? kLeftLastPath : kRightLastPath
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

    // / Attempts to load the last focus'd panel side from config
    private static func loadSideFromConfig() -> PanelSide? {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: kLastFocusedPanel), let s = parsePanelSide(raw) {
            return s
        }
        return nil
    }

    // MARK: - Designated initializer
    init(side: PanelSide = .left, initialPath: String? = nil) {
        // Prefer side<-config if available; otherwise use passed-in value
        let restoredSide = SelectedDir.loadSideFromConfig() ?? side
        // Determine start path: explicit param > config > default
        let configPath = SelectedDir.resolveStartPath(for: restoredSide)
        let startPath = initialPath ?? configPath ?? "/tmp"

        // Log what we restored
        if initialPath != nil {
            log.info("\(#function) side= <<\(restoredSide)>> (explicit path)")
        } else if configPath != nil {
            log.info("\(#function) side= <<\(restoredSide)>> (restored from config)")
        } else {
            log.info("\(#function) side= <<\(restoredSide)>> (using defaults)")
        }

        // init sel with resolved path
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
