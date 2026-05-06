// FilePanelStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.08.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Static layout constants for file panels.
//   Selection/text colors are served live from ColorThemeStore.

import AppKit
import SwiftUI

// MARK: - Visual styling constants for file panels
enum FilePanelStyle {

    private static var backingScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2.0
    }

    private static func pixelSnapped(_ value: CGFloat) -> CGFloat {
        (value * backingScale).rounded() / backingScale
    }

    // MARK: - Layout - Finder style (standard macOS sizes)
    /// Base icon size - 16pt (Finder list view standard)
    private static let baseIconSize: CGFloat = 16

    // MARK: - Row Density
    /// Supported row density presets
    enum RowDensity: String, CaseIterable {
        case compact = "compact"  // 18 pt
        case normal = "normal"  // 22 pt  (Finder default)
        case relaxed = "relaxed"  // 28 pt
        case spacious = "spacious"  // 34 pt

        var baseHeight: CGFloat {
            switch self {
                case .compact: return 18
                case .normal: return 22
                case .relaxed: return 28
                case .spacious: return 34
            }
        }
        var label: String {
            switch self {
                case .compact: return "Compact (18 pt)"
                case .normal: return "Normal (22 pt)"
                case .relaxed: return "Relaxed (28 pt)"
                case .spacious: return "Spacious (34 pt)"
            }
        }
    }

    /// Base row height resolved from MiMiDefaults density setting
    @MainActor
    private static var baseRowHeight: CGFloat {
        let raw = MiMiDefaults.shared.string(forKey: "settings.panels.rowDensity") ?? "normal"
        return (RowDensity(rawValue: raw) ?? .normal).baseHeight
    }

    /// Icon size - scaled by InterfaceScaleStore
    @MainActor static var iconSize: CGFloat { pixelSnapped(InterfaceScaleStore.shared.scaled(baseIconSize)) }

    /// Row height - scaled by InterfaceScaleStore
    @MainActor static var rowHeight: CGFloat { pixelSnapped(InterfaceScaleStore.shared.scaled(baseRowHeight)) }
}
