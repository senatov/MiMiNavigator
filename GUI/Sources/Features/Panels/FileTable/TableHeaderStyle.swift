// TableHeaderStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Visual styling constants for column headers.

import SwiftUI

// MARK: - TableHeaderStyle
enum TableHeaderStyle {
    /// Standard black for inactive column titles
    static let color = Color(nsColor: .labelColor)
    /// Active sort column title weight — .light for clear contrast with light base
    static let sortActiveWeight: Font.Weight = .light
    /// No background highlight for active sort column
    static let backgroundColor = Color(nsColor: .controlBackgroundColor)
}
