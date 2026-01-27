// DesignTokens.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.10.2024.
// Refactored: 27.01.2026
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
    
    /// Standard corner radius
    static let radius: CGFloat = 8
    
    /// Horizontal spacing between elements
    static let horizontalSpacing: CGFloat = 8
    
    // MARK: - Colors
    /// Card background color (window background)
    static let card = Color(nsColor: .windowBackgroundColor)
    
    /// Panel background color (control background)
    static let panelBg = Color(nsColor: .controlBackgroundColor)
    
    /// Separator color
    static let separator = Color(nsColor: .separatorColor)
    
    // MARK: - Row-specific Tokens
    enum Row {
        /// Icon size - matches FilePanelStyle for consistency
        static let iconSize: CGFloat = FilePanelStyle.iconSize
        
        /// Row vertical padding
        static let padding: CGFloat = 2
        
        /// Horizontal spacing between elements
        static let spacing: CGFloat = 8
    }
}

// MARK: - Deprecated Typealias (for backward compatibility)
enum RowDesignTokens {
    static let grid: CGFloat = DesignTokens.grid
    static let iconSize: CGFloat = DesignTokens.Row.iconSize
    static let rowPadding: CGFloat = DesignTokens.Row.padding
    static let horizontalSpacing: CGFloat = DesignTokens.Row.spacing
}
