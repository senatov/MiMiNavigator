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
final class DividerAppearance {
    var normalThickness: CGFloat = 4.0
    var activeThickness: CGFloat = 6.0
    var normalColor: NSColor { NSColor(ColorThemeStore.shared.activeTheme.dividerNormalColor) }
    var activeColor: NSColor { NSColor(ColorThemeStore.shared.activeTheme.dividerActiveColor) }
    var hitExpansion: CGFloat = 24
    var isDragging: Bool = false
}
