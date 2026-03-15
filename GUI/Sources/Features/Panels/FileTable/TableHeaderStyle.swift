// TableHeaderStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Visual styling constants for column headers.

import SwiftUI

// MARK: - TableHeaderStyle
enum TableHeaderStyle {
    /// SF Pro Display Light 14 — scaled by InterfaceScaleStore
    @MainActor static var font: Font { Font.custom("SF Pro Display", size: InterfaceScaleStore.shared.scaledFontSize(14)).weight(.light) }
    /// Standard black for inactive column titles
    static let color = Color(nsColor: .labelColor)
    /// Very dark purple (almost black) for active sort column title + chevron
    @MainActor static var sortIndicatorColor: Color { ColorThemeStore.shared.activeTheme.dividerActiveColor }
    /// Active sort column title weight — semibold for clear contrast with light base
    static let sortActiveWeight: Font.Weight = .light
    /// No background highlight for active sort column
    static let backgroundColor = Color(nsColor: .controlBackgroundColor)
    static let separatorColor = Color(nsColor: .separatorColor)
}
