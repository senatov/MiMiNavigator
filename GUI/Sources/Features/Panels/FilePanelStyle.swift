// FilePanelStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.08.2024.
// Copyright © 2024 Senatov. All rights reserved.
// Description: Visual styling constants for file panels (macOS HIG compliant)

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

    /// Selected row fill (inactive)
    static let yellowSelRowFill = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)

    /// Selected row fill (active)
    static let orangeSelRowFill = Color(nsColor: .selectedContentBackgroundColor)

    // MARK: - Layout - Finder style (standard macOS sizes)

    /// Icon size - 16pt (Finder list view standard)
    static let iconSize: CGFloat = 16

    /// Row height - 22pt (Finder list view standard)
    static let rowHeight: CGFloat = 22

    /// Modified date column width
    static let modifiedColumnWidth: CGFloat = 145

    /// Selected row border width (not used in Finder style)
    static let selectedBorderWidth: CGFloat = 0

    /// Size column width
    static let sizeColumnWidth: CGFloat = 80

    /// Type column width
    static let typeColumnWidth: CGFloat = 100
}
