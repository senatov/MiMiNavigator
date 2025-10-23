//
//  RowDesignTokens.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: -Design tokens aligned with Figma macOS 26.1 (8pt grid)
enum RowDesignTokens {
    static let grid: CGFloat = 8
    static let radius: CGFloat = 6
    static let iconSize: CGFloat = FilePanelStyle.iconSize
    static let selBG = FilePanelStyle.yellowSelRowFill
    static let hoverBG = Color.primary.opacity(0.04)
}
