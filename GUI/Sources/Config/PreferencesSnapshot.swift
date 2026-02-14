// PreferencesSnapshot.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

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
            .urls(for: .downloadsDirectory, in: .userDomainMask)
            .first?
            .path ?? "/",
        rightPath: "/Users",
        showHiddenFiles: false,
        favoritesMaxDepth: 2,
        expandedFolders: [],
        lastSelectedLeftFilePath: nil,
        lastSelectedRightFilePath: nil
    )
}
