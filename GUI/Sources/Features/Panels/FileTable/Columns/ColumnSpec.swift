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
        self.width = max(width ?? id.defaultWidth, id.minWidth)
        self.isVisible = isVisible ?? id.defaultVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decode(ColumnID.self, forKey: .id)
        let decodedWidth = try container.decode(CGFloat.self, forKey: .width)
        let decodedVisible = try container.decode(Bool.self, forKey: .isVisible)
        self.id = decodedID
        // Persisted width can be stale — enforce current defaultWidth as floor
        self.width = max(decodedWidth, decodedID.defaultWidth)
        self.isVisible = decodedVisible
    }
}
