//
//  MenuCategory.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Combine
import Foundation

// MARK: - Represents a top-level menu category with a label and a list of items.
struct MenuCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let items: [MenuItem]
}
