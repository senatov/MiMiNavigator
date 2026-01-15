// FileSnapshot.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - File state snapshot for change detection
struct FileSnapshot: Codable, Equatable {
    var size: Int64
    var mtime: Date?
}
