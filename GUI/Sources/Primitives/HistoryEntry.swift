// HistoryEntry.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - History entry for navigation tracking
struct HistoryEntry: Codable, Equatable {
    var path: String
    var timestamp: Date
    var status: Status
    var snapshot: FileSnapshot?

    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool { 
        lhs.path == rhs.path 
    }
}
