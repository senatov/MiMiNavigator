//
//  PanelDividerStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - Divider Style Constants
enum PanelDividerMetrics {
    enum Colors {
        // Subtle bluish border for groove edges
        static let grooveBorder = Color(red: 0.35, green: 0.55, blue: 0.85).opacity(0.35)
        static let grooveBorderActive = Color(red: 0.35, green: 0.55, blue: 0.85).opacity(0.6)
        static let activeLine = Color(red: 0.95, green: 0.72, blue: 0.44).opacity(0.78)
        static let activeLineEdge = Color(red: 1.0, green: 0.80, blue: 0.56).opacity(0.52)
        static let handleFillTop = Color.white.opacity(0.92)
        static let handleFillBottom = Color(red: 0.92, green: 0.95, blue: 0.98).opacity(0.82)
        static let handleAccent = Color(red: 1.0, green: 0.77, blue: 0.48).opacity(0.30)
        static let handleBorder = Color.white.opacity(0.62)
        static let handleShadow = Color.black.opacity(0.28)
        static let handleGlyph = Color.black.opacity(0.50)
    }

    // MARK: - Layout
    /// Invisible hit zone for comfortable drag interaction
    static let hitAreaWidth: CGFloat = 24

    /// Default divider visual thickness (inactive)
    static let normalWidth: CGFloat = 1.5

    /// Divider thickness during active dragging
    static let activeWidth: CGFloat = 3.0

    /// Minimal allowed panel width to avoid layout collapse
    static let minPanelWidth: CGFloat = 80

    static let grooveWidth: CGFloat = 6
    static let handleWidth: CGFloat = 16
    static let handleHeight: CGFloat = 34
    static let handleCornerRadius: CGFloat = 6
    static let glyphWidth: CGFloat = 1.25
    static let glyphHeight: CGFloat = 14
    static let glyphSpacing: CGFloat = 3.5
}
