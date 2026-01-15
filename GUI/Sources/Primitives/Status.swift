// Status.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - History entry status
enum Status: String, Codable {
    case added
    case modified
    case deleted
}
