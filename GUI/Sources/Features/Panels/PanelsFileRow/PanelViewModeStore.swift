// PanelViewModeStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Stores view mode and thumbnail size per panel, persisted in ~/.mimi/defaults.json.

import FileModelKit
import Foundation
import Observation

// MARK: - PanelViewModeStore
@MainActor
@Observable
final class PanelViewModeStore {

    // MARK: - Singleton
    static let shared = PanelViewModeStore()

    // MARK: - Keys
    private enum Keys {
        static let leftMode = "panelViewMode.left"
        static let rightMode = "panelViewMode.right"
        static let leftThumbSize = "panelThumbSize.left"
        static let rightThumbSize = "panelThumbSize.right"
    }

    // MARK: - State
    var leftMode: PanelViewMode {
        didSet { MiMiDefaults.shared.set(leftMode.rawValue, forKey: Keys.leftMode) }
    }
    var rightMode: PanelViewMode {
        didSet { MiMiDefaults.shared.set(rightMode.rawValue, forKey: Keys.rightMode) }
    }
    /// Thumbnail cell size 16…900 pt
    var leftThumbSize: CGFloat {
        didSet { MiMiDefaults.shared.set(Double(leftThumbSize), forKey: Keys.leftThumbSize) }
    }
    var rightThumbSize: CGFloat {
        didSet { MiMiDefaults.shared.set(Double(rightThumbSize), forKey: Keys.rightThumbSize) }
    }

    // MARK: - Init
    private init() {
        func loadMode(_ key: String) -> PanelViewMode {
            guard let raw = MiMiDefaults.shared.string(forKey: key) else { return .list }
            return PanelViewMode(rawValue: raw) ?? .list
        }
        func loadSize(_ key: String, default def: CGFloat) -> CGFloat {
            let v = MiMiDefaults.shared.double(forKey: key)
            return v > 0 ? CGFloat(v) : def
        }
        leftMode = loadMode(Keys.leftMode)
        rightMode = loadMode(Keys.rightMode)
        leftThumbSize = loadSize(Keys.leftThumbSize, default: 120)
        rightThumbSize = loadSize(Keys.rightThumbSize, default: 120)
    }

    // MARK: - Helpers
    func mode(for side: PanelSide) -> PanelViewMode {
        side == .left ? leftMode : rightMode
    }

    func setMode(_ mode: PanelViewMode, for side: PanelSide) {
        if side == .left { leftMode = mode } else { rightMode = mode }
    }

    func thumbSize(for side: PanelSide) -> CGFloat {
        side == .left ? leftThumbSize : rightThumbSize
    }

    func setThumbSize(_ size: CGFloat, for side: PanelSide) {
        let clamped = min(900, max(16, size))
        if side == .left { leftThumbSize = clamped } else { rightThumbSize = clamped }
    }
}
