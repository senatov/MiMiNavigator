// MenuItem.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - Menu item with action and optional keyboard shortcut
struct MenuItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let action: @MainActor @Sendable () -> Void
    let shortcut: String?

    // MARK: - Equatable
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
