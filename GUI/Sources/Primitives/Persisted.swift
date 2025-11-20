//
// Persisted.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Combine
import Foundation

// MARK: -
struct Persisted: Codable {
    var entries: [HistoryEntry]
    var currentIndex: Int?
}
