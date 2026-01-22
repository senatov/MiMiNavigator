// FilePanelStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//
// MARK: - Centralized color and layout constants for file panels
// Colors are defined in Assets.xcassets/Colors for visual editing and Dark Mode support

import SwiftUI

enum FilePanelStyle {
    
    // MARK: - File Name Colors (from Asset Catalog)
    
    /// Vibrant blue for symlink directories
    static let blueSymlinkDirNameColor = Color("SymlinkDirectory")
    
    /// Rich purple for regular directories
    static let dirNameColor = Color("DirectoryName")
    
    /// Higher contrast blue-gray for regular files
    static let fileNameColor = Color("FileName")
    
    // MARK: - Column Colors (Size, Date, Type)
    
    /// Rich brown for Size column
    static let sizeColumnColor = Color("SizeColumn")
    
    /// Rich green for Date column
    static let dateColumnColor = Color("DateColumn")
    
    /// Rich purple for Type column
    static let typeColumnColor = Color("TypeColumn")
    
    // MARK: - Header & Divider Colors
    
    /// Dark blue for table headers
    static let headerColor = Color("TableHeader")
    
    /// Dark navy for column dividers
    static let columnDividerColor = Color("ColumnDivider")
    
    // MARK: - Selection Colors
    
    /// Orange stroke for selected row
    static let orangeSelRowStroke = Color("SelectionOrangeStroke")
    
    /// Light blue accent
    static let skyBlueColor = Color("SkyBlue")
    
    /// Yellow fill for selected row (inactive)
    static let yellowSelRowFill = Color("SelectionYellowFill")
    
    /// Orange fill for active selection
    static let orangeSelRowFill = Color("SelectionOrangeFill")
    
    // MARK: - Help Popup Colors
    
    /// Brown text for help popup
    static let helpPopupTextColor = Color("HelpPopupText")

    // MARK: - Corner Radius (macOS HIG aligned)
    
    /// Standard small buttons, text fields
    static let buttonCornerRadius: CGFloat = 6
    
    /// Toolbar buttons, larger interactive elements
    static let toolbarButtonRadius: CGFloat = 8
    
    /// Panels, cards, table containers
    static let containerCornerRadius: CGFloat = 10
    
    /// Windows, popovers, sheets
    static let windowCornerRadius: CGFloat = 12
    
    /// Row selection highlight
    static let rowSelectionRadius: CGFloat = 4

    // MARK: - Layout Constants (Total Commander style)
    
    /// Icon size - 22pt for crisp display
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
