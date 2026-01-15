// Persisted.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - Persisted history state
struct Persisted: Codable {
    var entries: [HistoryEntry]
    var currentIndex: Int?
}
