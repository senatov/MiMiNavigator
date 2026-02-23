// DesignTokens.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.10.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Centralized design tokens for consistent UI styling

import AppKit
import SwiftUI

// MARK: - Design Tokens
/// Centralized design constants for maintaining consistent visual appearance.
/// Based on an 8pt grid system.
enum DesignTokens {
    
    // MARK: - Grid & Spacing
    /// Base grid unit (8pt)
    static let grid: CGFloat = 8
    
    /// Standard corner radius (HIG: 8pt for cards/panels)
    static let radius: CGFloat = 8
    
    /// Small corner radius (HIG: 4-6pt for buttons/controls)
    static let radiusSmall: CGFloat = 6
    
    /// Tiny corner radius (HIG: 4pt for rows/selections)
    static let radiusTiny: CGFloat = 4
    
    /// Horizontal spacing between elements
    static let horizontalSpacing: CGFloat = 8
    
    // MARK: - Colors
    /// Card background color (window background)
    static let card = Color(nsColor: .windowBackgroundColor)
    
    /// Panel background color (control background)
    static let panelBg = Color(nsColor: .controlBackgroundColor)

    /// Warm white background for active panel and session table
    static let warmWhite = Color(#colorLiteral(red: 0.9744921875, green: 0.9672388187, blue: 0.9454787124, alpha: 0.9061729754))

    /// Separator color
    static let separator = Color(nsColor: .separatorColor)
    
    // MARK: - Row-specific Tokens (Finder-style)
    enum Row {
        /// Icon size - 16pt (Finder list view standard)
        static let iconSize: CGFloat = FilePanelStyle.iconSize
        
        /// Row vertical padding
        static let padding: CGFloat = 2
        
        /// Horizontal spacing between elements
        static let spacing: CGFloat = 6
    }
}
