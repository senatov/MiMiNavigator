//
// FileSnapshot.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Combine
// MARK: -
import Foundation

// MARK: -
struct FileSnapshot: Codable, Equatable {
    var size: Int64
    var mtime: Date?
}
