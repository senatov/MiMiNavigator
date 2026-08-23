// PreviewPaneStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.08.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent presentation state for the workspace Preview pane.

import Foundation

// MARK: - Preview Pane Store
@MainActor
@Observable
final class PreviewPaneStore {
    static let shared = PreviewPaneStore()
    private enum Keys {
        static let isVisible = "workspace.preview.isVisible"
        static let width = "workspace.preview.width"
    }
    static let defaultWidth: CGFloat = 320
    static let minimumWidth: CGFloat = 240
    static let maximumWidth: CGFloat = 520
    var isVisible: Bool {
        didSet {
            MiMiDefaults.shared.set(isVisible, forKey: Keys.isVisible)
            log.info("[Preview] visibility=\(isVisible)")
        }
    }
    var width: CGFloat {
        didSet {
            let constrained = min(max(width, Self.minimumWidth), Self.maximumWidth)
            if constrained != width {
                width = constrained
                return
            }
            MiMiDefaults.shared.set(Double(width), forKey: Keys.width)
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
        let storedWidth = CGFloat(defaults.double(forKey: Keys.width))
        width = storedWidth > 0 ? min(max(storedWidth, Self.minimumWidth), Self.maximumWidth) : Self.defaultWidth
    }

    // MARK: - Toggle
    func toggle() {
        isVisible.toggle()
    }
}
