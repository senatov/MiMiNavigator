//
//  MenuCategory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.01.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
import SwiftUI

// MARK: - Supporting Structures
struct MenuCategory: Identifiable {
    let id = UUID()
    let titleStr: String
    let items: [MenuItem]

    init(title: String, items: [MenuItem]) {
        self.titleStr = title
        self.items = items
    }
}
