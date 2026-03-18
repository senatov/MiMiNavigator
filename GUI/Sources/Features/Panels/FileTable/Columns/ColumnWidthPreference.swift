// ColumnWidthPreference.swift
// MiMiNavigator
// Created by Iakov Senatov on 18.03.2026.
// Description: PreferenceKey — collects real rendered widths of fixed columns
//              from GeometryReader in TableHeaderView headers.
//              FileRowMetadataColumnsView reads the same spec.width → pixel-perfect sync.

import SwiftUI

// MARK: - ColumnWidthEntry

struct ColumnWidthEntry: Equatable {
    let id: ColumnID
    let width: CGFloat
}

// MARK: - ColumnWidthPreferenceKey

struct ColumnWidthPreferenceKey: PreferenceKey {
    static let defaultValue: [ColumnWidthEntry] = []
    static func reduce(value: inout [ColumnWidthEntry], nextValue: () -> [ColumnWidthEntry]) {
        value.append(contentsOf: nextValue())
    }
}
