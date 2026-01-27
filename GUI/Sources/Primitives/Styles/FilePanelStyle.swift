// FilePanelStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Visual styling constants for file panels
// Inspired by Total Commander aesthetics
enum FilePanelStyle {
    
    // MARK: - Colors
    
    /// Blue color for symlink directories
    static let blueSymlinkDirNameColor = Color(red: 0.24, green: 0.29, blue: 0.87)
    
    /// Purple color for regular directories
    static let dirNameColor = Color(red: 0.18, green: 0.01, blue: 0.56)
    
    /// Dark blue-gray for regular files
    static let fileNameColor = Color(red: 0.06, green: 0.18, blue: 0.25)
    
    /// Orange stroke for selected row
    static let orangeSelRowStroke = Color(red: 0.94, green: 0.50, blue: 0.35)
    
    /// Light blue accent
    static let skyBlauColor = Color(red: 0.47, green: 0.84, blue: 0.98)
    
    /// Yellow fill for selected row
    static let yellowSelRowFill = Color(red: 1.0, green: 0.98, blue: 0.92)
    
    /// Orange fill for active selection
    static let orangeSelRowFill = Color(red: 0.98, green: 0.85, blue: 0.55)

    // MARK: - Layout - Total Commander style (larger icons for clarity)
    
    /// Icon size - 22pt for crisp display like Total Commander
    static let iconSize: CGFloat = 22
    
    /// Row height for comfortable reading
    static let rowHeight: CGFloat = 24
    
    /// Modified date column width
    static let modifiedColumnWidth: CGFloat = 110
    
    /// Selected row border width
    static let selectedBorderWidth: CGFloat = 0.4
    
    /// Size column width
    static let sizeColumnWidth: CGFloat = 85
    
    /// Type column width
    static let typeColumnWidth: CGFloat = 75
}
