//
//  HistoryEntry.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Combine
import Foundation

// MARK: -
struct HistoryEntry: Codable, Equatable {
    var path: String
    var timestamp: Date
    var status: Status
    var snapshot: FileSnapshot?

    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool { lhs.path == rhs.path }
}
