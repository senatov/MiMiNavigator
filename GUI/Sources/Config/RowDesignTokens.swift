// RowDesignTokens.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Design tokens for file rows (aligned with 8pt grid)
enum RowDesignTokens {
    /// Base grid unit (8pt)
    static let grid: CGFloat = 8
    
    /// Icon size - matches FilePanelStyle for consistency
    static let iconSize: CGFloat = FilePanelStyle.iconSize
    
    /// Row vertical padding
    static let rowPadding: CGFloat = 2
    
    /// Horizontal spacing between elements
    static let horizontalSpacing: CGFloat = 8
}
