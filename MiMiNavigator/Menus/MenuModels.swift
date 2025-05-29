//
//  MenuItem 2.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

/// Represents a single menu item with a title, action closure, and optional keyboard shortcut.
struct MenuItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let action: () -> Void
    let shortcut: String?

    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents a top-level menu category with a label and a list of items.
struct MenuCategory: Identifiable, Hashable {
    let id = UUID()
    let titleStr: String
    let items: [MenuItem]
}
