// TableColumnDefaults.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Default constraints and padding for resizable columns.

import SwiftUI

// MARK: - TableColumnDefaults
/// Universal min/max and padding for all columns.
enum TableColumnDefaults {
    static let minWidth: CGFloat = 40
    static let maxWidth: CGFloat = 200
    /// Horizontal padding applied INSIDE each fixed column cell (header AND row must use same value)
    static let cellPadding: CGFloat = 6
}

// MARK: - TableColumnConstraints
/// Min/max constraints for column resizing (per-column specific).
enum TableColumnConstraints {
    static let sizeMin: CGFloat = 30
    static let sizeMax: CGFloat = 120
    static let dateMin: CGFloat = 80
    static let dateMax: CGFloat = 160
    static let typeMin: CGFloat = 50
    static let typeMax: CGFloat = 120
    static let permissionsMin: CGFloat = 60
    static let permissionsMax: CGFloat = 100
    static let ownerMin: CGFloat = 50
    static let ownerMax: CGFloat = 120
}
