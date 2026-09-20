// PreviewPaneStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.08.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent presentation state for the workspace Preview pane.

import Foundation
import FileModelKit

// MARK: - Preview Pane Store
@MainActor
@Observable
final class PreviewPaneStore {
    static let shared = PreviewPaneStore()
    private enum Keys {
        static let isVisible = "workspace.preview.isVisible"
        static let side = "workspace.preview.side"
    }
    var isVisible: Bool {
        didSet {
            MiMiDefaults.shared.set(isVisible, forKey: Keys.isVisible)
            log.info("[Preview] visibility=\(isVisible)")
        }
    }
    var previewSide: FavPanelSide {
        didSet {
            MiMiDefaults.shared.set(previewSide.rawValue, forKey: Keys.side)
            log.info("[Preview] side=\(previewSide.rawValue)")
        }
    }

    // MARK: - Init
    private init() {
        let defaults = MiMiDefaults.shared
        if defaults.object(forKey: Keys.isVisible) == nil {
            isVisible = false
        } else {
            isVisible = defaults.bool(forKey: Keys.isVisible)
        }
        let storedSide = defaults.string(forKey: Keys.side) ?? "right"
        previewSide = FavPanelSide(rawValue: storedSide) ?? .right
    }

    // MARK: - Toggle
    func toggle(sourceSide: FavPanelSide) {
        if isVisible {
            isVisible = false
        } else {
            previewSide = sourceSide.opposite
            isVisible = true
        }
    }

    // MARK: - Swap Side
    func swapSide() {
        previewSide = previewSide.opposite
    }
}
