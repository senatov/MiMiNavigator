//
//  PrefKey.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Combine
import Foundation

// MARK: - PrefKey
private enum PrefKey: String, CaseIterable {
    case leftPath
    case rightPath
    case showHiddenFiles
    case favoritesMaxDepth
    case expandedFolders
    case lastSelectedLeftFilePath
    case lastSelectedRightFilePath
}
