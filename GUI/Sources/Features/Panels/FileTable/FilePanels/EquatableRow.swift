//
//  EquatableRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

// MARK: - EquatableRow
struct EquatableRow<Content: View>: View, Equatable {

    let id: CustomFile.ID
    let isSelected: Bool
    let layoutVersion: Int
    var isParent: Bool = false
    @ViewBuilder let content: () -> Content

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.isSelected == rhs.isSelected && lhs.layoutVersion == rhs.layoutVersion
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowBackground)
    }

    private var rowBackground: Color {
        if isParent { return .clear }
        return isSelected ? Color.accentColor.opacity(0.20) : .clear
    }
}
