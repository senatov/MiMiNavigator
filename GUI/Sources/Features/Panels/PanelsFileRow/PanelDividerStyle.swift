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
    }

    // MARK: - Layout
    /// Invisible hit zone for comfortable drag interaction
    static let hitAreaWidth: CGFloat = 24

    /// Default divider visual thickness (inactive)
    static let normalWidth: CGFloat = 2.0

    /// Divider thickness during active dragging
    static let activeWidth: CGFloat = 5.0

    /// Minimal allowed panel width to avoid layout collapse
    static let minPanelWidth: CGFloat = 80
}
