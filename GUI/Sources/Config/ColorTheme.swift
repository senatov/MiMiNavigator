//
//  ColorTheme.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: ColorTheme model and built-in presets (Default, Warm, Midnight, Solarized).
//               Extracted from SettingsColorsPane.swift for single-responsibility.

import AppKit
import SwiftUI

// MARK: - ColorTheme
struct ColorTheme: Identifiable, Equatable {
    let id: String
    let name: String
    // Panel
    var panelBackground: Color
    var panelText: Color
    var dirNameColor: Color
    var fileNameColor: Color
    var symlinkColor: Color
    // Selection
    var selectionActive: Color
    var selectionInactive: Color
    var selectionBorder: Color
    var selectionLineWidth: CGFloat
    // UI chrome
    var separatorColor: Color
    var dialogBase: Color
    var dialogStripe: Color
    var accentColor: Color
    /// Background of floating dialog windows (Find Files, Settings, etc.)
    var dialogBackground: Color
    // Special file states
    var hiddenFileColor: Color
    var markedFileColor: Color
    var parentEntryColor: Color
    var archivePathColor: Color
    var markedCountColor: Color
    // Column accent colors
    var columnNameColor: Color
    var columnSizeColor: Color
    var columnKindColor: Color
    var columnDateColor: Color
    var columnPermissionsColor: Color
    var columnOwnerColor: Color
    var columnGroupColor: Color
    var columnChildCountColor: Color
    // Panel divider
    var dividerNormalColor: Color
    var dividerActiveColor: Color
    // Panel border
    var panelBorderActive: Color
    var panelBorderInactive: Color
    var panelBorderWidth: CGFloat
    // Zebra stripe base for active panel
    var warmWhite: Color
    // Zebra stripe colors (active panel: warm aged-paper, inactive: neutral near-white)
    var zebraActiveEven: Color
    var zebraActiveOdd: Color
    var zebraInactiveEven: Color
    var zebraInactiveOdd: Color
    // Filter bar active highlight
    var filterActiveColor: Color
    // Dark variants (nil = same as light)
    var panelBackgroundDark: Color?
    var panelTextDark: Color?
    var dirNameColorDark: Color?
    var selectionActiveDark: Color?
}

// MARK: - Built-in Presets
extension ColorTheme {

    // MARK: - defaultTheme
    /// Default — matches current hardcoded values exactly
    static let defaultTheme = ColorTheme(
        id: "default",
        name: "Default",
        panelBackground:    Color(nsColor: .controlBackgroundColor),
        panelText:          Color.primary,
        dirNameColor:       Color.primary,
        fileNameColor:      Color.primary,
        symlinkColor:       Color(nsColor: .linkColor),
        selectionActive:    Color(red: 255/255, green: 255/255, blue: 220/255),
        selectionInactive:  Color(nsColor: .unemphasizedSelectedContentBackgroundColor),
        selectionBorder:    Color(red: 0/255, green: 100/255, blue: 225/255),
        selectionLineWidth: 2.0,
        separatorColor:     Color(nsColor: .separatorColor),
        dialogBase:         Color(red: 239/255, green: 239/255, blue: 239/255),
        dialogStripe:       Color(red: 231/255, green: 231/255, blue: 231/255),
        accentColor:        Color.accentColor,
        dialogBackground:   Color(red: 239/255, green: 239/255, blue: 239/255),
        hiddenFileColor:     Color(red: 0.38, green: 0.38, blue: 0.38),
        markedFileColor:     Color(red: 0.45, green: 0.0, blue: 0.0),
        parentEntryColor:    Color(red: 0.2, green: 0.2, blue: 0.7),
        archivePathColor:    Color(red: 0.1, green: 0.1, blue: 0.55),
        markedCountColor:    Color(red: 0.7, green: 0.0, blue: 0.0),
        columnNameColor:     Color(red: 0.05, green: 0.10, blue: 0.30),
        columnSizeColor:     Color(red: 0.50, green: 0.05, blue: 0.18),
        columnKindColor:     Color(red: 0.28, green: 0.14, blue: 0.05),
        columnDateColor:     Color(red: 0.05, green: 0.28, blue: 0.10),
        columnPermissionsColor: Color(red: 0.22, green: 0.22, blue: 0.40),
        columnOwnerColor:       Color(red: 0.20, green: 0.30, blue: 0.20),
        columnGroupColor:       Color(red: 0.28, green: 0.20, blue: 0.30),
        columnChildCountColor:  Color(red: 0.30, green: 0.20, blue: 0.10),
        dividerNormalColor:  Color(red: 0.42, green: 0.42, blue: 0.46, opacity: 0.55),
        dividerActiveColor:  Color(red: 0.22, green: 0.01, blue: 0.85, opacity: 0.90),
        panelBorderActive:   Color(red: 0.10, green: 0.15, blue: 0.58, opacity: 0.72),
        panelBorderInactive: Color(red: 0.45, green: 0.45, blue: 0.50, opacity: 0.38),
        panelBorderWidth:    1.5,
        warmWhite:           Color(red: 0.97, green: 0.97, blue: 0.95, opacity: 0.91),
        zebraActiveEven:     Color(red: 0.99, green: 0.985, blue: 0.965),
        zebraActiveOdd:      Color(red: 0.98, green: 0.97, blue: 0.94),
        zebraInactiveEven:   Color(red: 0.985, green: 0.985, blue: 0.985),
        zebraInactiveOdd:    Color(red: 0.93, green: 0.93, blue: 0.925),
        filterActiveColor:   Color(red: 0.25, green: 0.55, blue: 1.0, opacity: 0.8),
        panelBackgroundDark: Color(nsColor: .windowBackgroundColor),
        panelTextDark:       Color.primary,
        dirNameColorDark:    Color.primary,
        selectionActiveDark: Color(nsColor: .selectedContentBackgroundColor)
    )

    // MARK: - warmTheme
    /// Warm — amber/cream tones like ForkLift's warm mode
    static let warmTheme = ColorTheme(
        id: "warm",
        name: "Warm",
        panelBackground:    Color(red: 252/255, green: 248/255, blue: 240/255),
        panelText:          Color(red: 40/255,  green: 35/255,  blue: 28/255),
        dirNameColor:       Color(red: 80/255,  green: 60/255,  blue: 20/255),
        fileNameColor:      Color(red: 40/255,  green: 35/255,  blue: 28/255),
        symlinkColor:       Color(red: 180/255, green: 100/255, blue: 20/255),
        selectionActive:    Color(red: 255/255, green: 200/255, blue: 100/255),
        selectionInactive:  Color(red: 250/255, green: 235/255, blue: 200/255),
        selectionBorder:    Color(red: 210/255, green: 150/255, blue: 60/255).opacity(0.5),
        selectionLineWidth: 2.0,
        separatorColor:     Color(red: 200/255, green: 185/255, blue: 160/255),
        dialogBase:         Color(red: 250/255, green: 245/255, blue: 235/255),
        dialogStripe:       Color(red: 245/255, green: 238/255, blue: 224/255),
        accentColor:        Color(red: 210/255, green: 140/255, blue: 40/255),
        dialogBackground:   Color(red: 252/255, green: 248/255, blue: 240/255).opacity(0.92),
        hiddenFileColor:     Color(red: 0.55, green: 0.48, blue: 0.38),
        markedFileColor:     Color(red: 0.60, green: 0.15, blue: 0.0),
        parentEntryColor:    Color(red: 0.50, green: 0.35, blue: 0.10),
        archivePathColor:    Color(red: 0.40, green: 0.25, blue: 0.05),
        markedCountColor:    Color(red: 0.70, green: 0.20, blue: 0.0),
        columnNameColor:     Color(red: 0.35, green: 0.25, blue: 0.10),
        columnSizeColor:     Color(red: 0.55, green: 0.25, blue: 0.10),
        columnKindColor:     Color(red: 0.40, green: 0.28, blue: 0.12),
        columnDateColor:     Color(red: 0.30, green: 0.38, blue: 0.12),
        columnPermissionsColor: Color(red: 0.48, green: 0.38, blue: 0.20),
        columnOwnerColor:       Color(red: 0.40, green: 0.42, blue: 0.20),
        columnGroupColor:       Color(red: 0.45, green: 0.30, blue: 0.25),
        columnChildCountColor:  Color(red: 0.50, green: 0.30, blue: 0.15),
        dividerNormalColor:  Color(red: 0.60, green: 0.55, blue: 0.45, opacity: 0.55),
        dividerActiveColor:  Color(red: 0.82, green: 0.55, blue: 0.15, opacity: 0.90),
        panelBorderActive:   Color(red: 0.70, green: 0.55, blue: 0.30, opacity: 0.55),
        panelBorderInactive: Color(red: 0.60, green: 0.55, blue: 0.45, opacity: 0.38),
        panelBorderWidth:    1.5,
        warmWhite:           Color(red: 0.99, green: 0.97, blue: 0.92, opacity: 0.91),
        zebraActiveEven:     Color(red: 0.99, green: 0.975, blue: 0.94),
        zebraActiveOdd:      Color(red: 0.98, green: 0.96, blue: 0.91),
        zebraInactiveEven:   Color(red: 0.98, green: 0.975, blue: 0.965),
        zebraInactiveOdd:    Color(red: 0.94, green: 0.935, blue: 0.92),
        filterActiveColor:   Color(red: 0.75, green: 0.50, blue: 0.10, opacity: 0.8),
        panelBackgroundDark: Color(red: 40/255, green: 35/255, blue: 28/255),
        panelTextDark:       Color(red: 240/255, green: 225/255, blue: 200/255),
        dirNameColorDark:    Color(red: 255/255, green: 200/255, blue: 120/255),
        selectionActiveDark: Color(red: 100/255, green: 75/255, blue: 30/255)
    )

    // MARK: - midnightTheme
    /// Midnight — dark blue like Nova / Sublime Text
    static let midnightTheme = ColorTheme(
        id: "midnight",
        name: "Midnight",
        panelBackground:    Color(red: 30/255,  green: 35/255,  blue: 50/255),
        panelText:          Color(red: 210/255, green: 215/255, blue: 230/255),
        dirNameColor:       Color(red: 130/255, green: 180/255, blue: 255/255),
        fileNameColor:      Color(red: 210/255, green: 215/255, blue: 230/255),
        symlinkColor:       Color(red: 100/255, green: 220/255, blue: 200/255),
        selectionActive:    Color(red: 50/255,  green: 80/255,  blue: 130/255),
        selectionInactive:  Color(red: 40/255,  green: 50/255,  blue: 75/255),
        selectionBorder:    Color(red: 80/255,  green: 130/255, blue: 220/255).opacity(0.6),
        selectionLineWidth: 2.0,
        separatorColor:     Color(red: 55/255,  green: 65/255,  blue: 90/255),
        dialogBase:         Color(red: 35/255,  green: 40/255,  blue: 58/255),
        dialogStripe:       Color(red: 28/255,  green: 33/255,  blue: 50/255),
        accentColor:        Color(red: 80/255,  green: 150/255, blue: 255/255),
        dialogBackground:   Color(red: 30/255,  green: 35/255,  blue: 50/255).opacity(0.92),
        hiddenFileColor:     Color(red: 0.45, green: 0.48, blue: 0.55),
        markedFileColor:     Color(red: 1.0, green: 0.45, blue: 0.35),
        parentEntryColor:    Color(red: 0.55, green: 0.70, blue: 1.0),
        archivePathColor:    Color(red: 0.50, green: 0.65, blue: 1.0),
        markedCountColor:    Color(red: 1.0, green: 0.40, blue: 0.35),
        columnNameColor:     Color(red: 0.50, green: 0.65, blue: 0.90),
        columnSizeColor:     Color(red: 0.85, green: 0.50, blue: 0.60),
        columnKindColor:     Color(red: 0.70, green: 0.60, blue: 0.50),
        columnDateColor:     Color(red: 0.45, green: 0.75, blue: 0.55),
        columnPermissionsColor: Color(red: 0.65, green: 0.60, blue: 0.85),
        columnOwnerColor:       Color(red: 0.50, green: 0.80, blue: 0.65),
        columnGroupColor:       Color(red: 0.70, green: 0.55, blue: 0.80),
        columnChildCountColor:  Color(red: 0.75, green: 0.70, blue: 0.50),
        dividerNormalColor:  Color(red: 0.35, green: 0.40, blue: 0.55, opacity: 0.60),
        dividerActiveColor:  Color(red: 0.40, green: 0.60, blue: 1.0, opacity: 0.90),
        panelBorderActive:   Color(red: 0.35, green: 0.50, blue: 0.80, opacity: 0.60),
        panelBorderInactive: Color(red: 0.30, green: 0.35, blue: 0.50, opacity: 0.40),
        panelBorderWidth:    1.5,
        warmWhite:           Color(red: 0.16, green: 0.18, blue: 0.26, opacity: 0.50),
        zebraActiveEven:     Color(red: 0.14, green: 0.16, blue: 0.24),
        zebraActiveOdd:      Color(red: 0.12, green: 0.14, blue: 0.21),
        zebraInactiveEven:   Color(red: 0.15, green: 0.15, blue: 0.18),
        zebraInactiveOdd:    Color(red: 0.12, green: 0.12, blue: 0.15),
        filterActiveColor:   Color(red: 0.40, green: 0.65, blue: 1.0, opacity: 0.8),
        panelBackgroundDark: nil,
        panelTextDark:       nil,
        dirNameColorDark:    nil,
        selectionActiveDark: nil
    )

    // MARK: - solarizedTheme
    /// Solarized — classic terminal palette
    static let solarizedTheme = ColorTheme(
        id: "solarized",
        name: "Solarized",
        panelBackground:    Color(red: 253/255, green: 246/255, blue: 227/255),
        panelText:          Color(red: 101/255, green: 123/255, blue: 131/255),
        dirNameColor:       Color(red: 38/255,  green: 139/255, blue: 210/255),
        fileNameColor:      Color(red: 101/255, green: 123/255, blue: 131/255),
        symlinkColor:       Color(red: 42/255,  green: 161/255, blue: 152/255),
        selectionActive:    Color(red: 238/255, green: 232/255, blue: 213/255),
        selectionInactive:  Color(red: 147/255, green: 161/255, blue: 161/255).opacity(0.2),
        selectionBorder:    Color(red: 38/255,  green: 139/255, blue: 210/255).opacity(0.4),
        selectionLineWidth: 2.0,
        separatorColor:     Color(red: 147/255, green: 161/255, blue: 161/255).opacity(0.5),
        dialogBase:         Color(red: 250/255, green: 244/255, blue: 222/255),
        dialogStripe:       Color(red: 245/255, green: 238/255, blue: 214/255),
        accentColor:        Color(red: 38/255,  green: 139/255, blue: 210/255),
        dialogBackground:   Color(red: 253/255, green: 246/255, blue: 227/255).opacity(0.92),
        hiddenFileColor:     Color(red: 0.58, green: 0.63, blue: 0.63),
        markedFileColor:     Color(red: 0.86, green: 0.20, blue: 0.18),
        parentEntryColor:    Color(red: 0.15, green: 0.55, blue: 0.82),
        archivePathColor:    Color(red: 0.15, green: 0.55, blue: 0.82),
        markedCountColor:    Color(red: 0.86, green: 0.20, blue: 0.18),
        columnNameColor:     Color(red: 0.15, green: 0.55, blue: 0.82),
        columnSizeColor:     Color(red: 0.52, green: 0.60, blue: 0.0),
        columnKindColor:     Color(red: 0.71, green: 0.54, blue: 0.0),
        columnDateColor:     Color(red: 0.16, green: 0.63, blue: 0.60),
        columnPermissionsColor: Color(red: 0.60, green: 0.20, blue: 0.00),
        columnOwnerColor:       Color(red: 0.52, green: 0.60, blue: 0.00),
        columnGroupColor:       Color(red: 0.71, green: 0.54, blue: 0.00),
        columnChildCountColor:  Color(red: 0.42, green: 0.16, blue: 0.51),
        dividerNormalColor:  Color(red: 0.58, green: 0.63, blue: 0.63, opacity: 0.50),
        dividerActiveColor:  Color(red: 0.15, green: 0.55, blue: 0.82, opacity: 0.90),
        panelBorderActive:   Color(red: 0.15, green: 0.55, blue: 0.82, opacity: 0.50),
        panelBorderInactive: Color(red: 0.58, green: 0.63, blue: 0.63, opacity: 0.35),
        panelBorderWidth:    1.5,
        warmWhite:           Color(red: 0.99, green: 0.96, blue: 0.89, opacity: 0.50),
        zebraActiveEven:     Color(red: 0.99, green: 0.965, blue: 0.89),
        zebraActiveOdd:      Color(red: 0.96, green: 0.94, blue: 0.86),
        zebraInactiveEven:   Color(red: 0.97, green: 0.96, blue: 0.94),
        zebraInactiveOdd:    Color(red: 0.93, green: 0.92, blue: 0.90),
        filterActiveColor:   Color(red: 0.15, green: 0.55, blue: 0.82, opacity: 0.8),
        panelBackgroundDark: Color(red: 0/255,   green: 43/255,  blue: 54/255),
        panelTextDark:       Color(red: 131/255, green: 148/255, blue: 150/255),
        dirNameColorDark:    Color(red: 38/255,  green: 139/255, blue: 210/255),
        selectionActiveDark: Color(red: 7/255,   green: 54/255,  blue: 66/255)
    )

    // MARK: - allPresets
    static let allPresets: [ColorTheme] = [.defaultTheme, .warmTheme, .midnightTheme, .solarizedTheme]
}
