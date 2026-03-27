//
// DividerAppearance.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Appearance carrier
@MainActor
final class DividerAppearance {
    var normalThickness: CGFloat = 5.0   // thick enough to show 3D gradient + edge lines
    var activeThickness: CGFloat = 7.0   // visibly wider while dragging
    var normalColor: NSColor { NSColor(ColorThemeStore.shared.activeTheme.dividerNormalColor) }
    var activeColor: NSColor { NSColor(ColorThemeStore.shared.activeTheme.dividerActiveColor) }
    var hitExpansion: CGFloat = 24
    var isDragging: Bool = false
}
