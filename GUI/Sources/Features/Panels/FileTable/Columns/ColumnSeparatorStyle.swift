// ColumnSeparatorStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Visual styling for column separators (both header and rows).

import SwiftUI

// MARK: - ColumnSeparatorStyle
enum ColumnSeparatorStyle {
    /// Dark navy blue for passive divider line (matches header text)
    @MainActor static var color: Color { ColorThemeStore.shared.activeTheme.dividerNormalColor }
    /// Light blue on cursor hover (stays blue)
    @MainActor static var hoverColor: Color { ColorThemeStore.shared.activeTheme.filterActiveColor }
    /// Bright blue while dragging (stays blue)
    @MainActor static var dragColor: Color { ColorThemeStore.shared.activeTheme.dividerActiveColor }
    /// Passive line width — 1pt ensures visibility at all display scales
    static let width: CGFloat = 1.0
    /// Active (hover/drag) line width
    static let activeWidth: CGFloat = 2.0
}

// MARK: - ColumnSeparator
/// Simple vertical separator between columns (non-resizable).
struct ColumnSeparator: View {
    var body: some View {
        Rectangle()
            .fill(ColumnSeparatorStyle.color)
            .frame(width: ColumnSeparatorStyle.width)
            .allowsHitTesting(false)
    }
}
