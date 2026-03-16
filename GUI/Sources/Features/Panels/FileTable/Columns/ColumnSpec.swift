// ColumnSpec.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single column specification — id, width, visibility.

import SwiftUI

// MARK: - ColumnSpec
struct ColumnSpec: Codable, Identifiable, Equatable {
    var id: ColumnID
    var width: CGFloat
    var isVisible: Bool

    init(id: ColumnID, width: CGFloat? = nil, isVisible: Bool? = nil) {
        self.id = id
        self.width = width ?? id.defaultWidth
        self.isVisible = isVisible ?? id.defaultVisible
    }
}
