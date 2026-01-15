// MenuCategory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - Represents a top-level menu category with a label and a list of items.
struct MenuCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let items: [MenuItem]
}
