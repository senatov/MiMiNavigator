//
//  FileSnapshot.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Combine
import Foundation

// MARK: -
import Foundation
import SwiftyBeaver

// MARK: -
struct FileSnapshot: Codable, Equatable {
    var size: Int64
    var mtime: Date?
}
