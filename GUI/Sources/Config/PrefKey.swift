// PrefKey.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - Preference keys for UserDefaults
enum PrefKey: String, CaseIterable {
    case leftPath
    case rightPath
    case showHiddenFiles
    case favoritesMaxDepth
    case expandedFolders
    case lastSelectedLeftFilePath
    case lastSelectedRightFilePath
}
