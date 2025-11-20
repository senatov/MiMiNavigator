//
// PrefsSnapshot.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//


import AppKit
import Combine
import Foundation

struct PreferencesSnapshot: Codable, Sendable {
    var leftPath: String
    var rightPath: String
    var showHiddenFiles: Bool
    var favoritesMaxDepth: Int
    var expandedFolders: Set<String>
    var lastSelectedLeftFilePath: String?
    var lastSelectedRightFilePath: String?

    static let `default` = PreferencesSnapshot(
        leftPath: FileManager.default
            .urls(
                for: .downloadsDirectory,
                in: .userDomainMask
            )
            .first?
            .path ?? "/",
        rightPath: FileManager.default
            .urls(
                for: .documentDirectory,
                in: .userDomainMask
            )
            .first?
            .path ?? "/",
        showHiddenFiles: false,
        favoritesMaxDepth: 2,
        expandedFolders: [],
        lastSelectedLeftFilePath: nil,
        lastSelectedRightFilePath: nil
    )
}