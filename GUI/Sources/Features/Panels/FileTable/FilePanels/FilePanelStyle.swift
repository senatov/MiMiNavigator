// FilePanelStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.08.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Static layout and fallback color constants for file panels.
//   Selection colors in FileRow and text colors in FileRowView are served
//   live from ColorThemeStore — constants here act as compile-time fallbacks only.

import SwiftUI

// MARK: - Visual styling constants for file panels
// Finder-style design (macOS HIG compliant)
enum FilePanelStyle {

    // MARK: - Colors (Finder-style: minimal color differentiation)
    /// Blue color for symlink directories (subtle differentiation)
    static let blueSymlinkDirNameColor = Color(nsColor: .linkColor)
    /// Directory name color (same as files in Finder)
    static let dirNameColor = Color.primary
    /// File name color
    static let fileNameColor = Color.primary
    /// Orange stroke for focused panel
    static let orangeSelRowStroke = Color.accentColor.opacity(0.5)
    /// Light blue accent
    static let skyBlauColor = Color.accentColor
    /// Selected row fill (active) — fallback constant; live value comes from ColorThemeStore in FileRow
    static let orangeSelRowFill = Color(nsColor: .selectedContentBackgroundColor)
    /// Selected row fill (inactive) — fallback constant; live value comes from ColorThemeStore in FileRow
    static let yellowSelRowFill = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
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
    @MainActor static var iconSize: CGFloat { InterfaceScaleStore.shared.scaled(baseIconSize) }

    /// Row height - scaled by InterfaceScaleStore
    @MainActor static var rowHeight: CGFloat { InterfaceScaleStore.shared.scaled(baseRowHeight) }

    /// Modified date column width
    static let modifiedColumnWidth: CGFloat = 145

    /// Selected row border width (not used in Finder style)
    static let selectedBorderWidth: CGFloat = 0

    /// Size column width
    static let sizeColumnWidth: CGFloat = 80

    /// Type column width
    static let typeColumnWidth: CGFloat = 100
}
