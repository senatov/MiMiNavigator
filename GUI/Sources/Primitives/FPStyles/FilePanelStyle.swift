    //
    //  FilePanelStyle.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 11.08.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import SwiftUI

enum FilePanelStyle {
        // Colors
    static let blueSymlinkDirNameColor = Color(#colorLiteral(red: 0.2392156863, green: 0.2901960784, blue: 0.8745098039, alpha: 1))
    static let dirNameColor = Color(#colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1))
    static let fileNameColor = Color(#colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1))
    static let orangeSelRowStroke = Color(#colorLiteral(red: 0.9411764741, green: 0.4980392158, blue: 0.3529411852, alpha: 1))
    static let skyBlauColor = Color(#colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1))
    static let yellowSelRowFill = Color(#colorLiteral(red: 0.9995340705, green: 0.9802359024, blue: 0.9185159122, alpha: 1))
    
        // Layout
    static let iconSize: CGFloat = 22
    static let modifiedColumnWidth: CGFloat = 110
    static let selectedBorderWidth: CGFloat = 0.4
    static let sizeColumnWidth: CGFloat = 120
    
        // Toolbar (bottom) style tokens
    static let toolbarBackgroundTint = Color.white.opacity(0.07)
    static let toolbarBottomPadding: CGFloat = 6
    static let toolbarCornerRadius: CGFloat = 14
    static let toolbarHairlineTop = Color.white.opacity(0.06)
    static let toolbarHorizontalPadding: CGFloat = 8
    static let toolbarMaterial: Material = .regularMaterial
    static let toolbarMinHeight: CGFloat = 44
    static let toolbarOuterRing = Color.white.opacity(0.10)
    static let toolbarStrokeInner = Color.white.opacity(0.03)
    static let toolbarStrokeOuter = Color.white.opacity(0.09)
    
        // New: toolbar shadow tokens used in DuoFilePanelView
    static let toolbarShadowColor = Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.18)
    static let toolbarShadowRadius: CGFloat = 8
    static let toolbarShadowYOffset: CGFloat = 2
    static let toolbarBottomOffset: CGFloat = 35
    
        // Toolbar button tokens
    static let buttonCornerRadius: CGFloat = 10
    static let buttonHoverStroke = FilePanelStyle.skyBlauColor.opacity(0.60)
    static let buttonIdleFill = Color.white.opacity(0.02)
    static let buttonIdleStroke = Color.primary.opacity(0.20)
    static let buttonPressedStroke = FilePanelStyle.skyBlauColor.opacity(0.90)
}
