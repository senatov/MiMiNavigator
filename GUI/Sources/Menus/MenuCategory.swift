// MenuCategory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2024.
//  Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Top-level menu category with optional SF Symbol icon.

import Foundation

// MARK: - Represents a top-level menu category with a label and a list of items.
struct MenuCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    /// SF Symbol name for the menu header (optional).
    let icon: String?
    let items: [MenuItem]

    init(title: String, icon: String? = nil, items: [MenuItem]) {
        self.title = title
        self.icon = icon
        self.items = items
    }
}
