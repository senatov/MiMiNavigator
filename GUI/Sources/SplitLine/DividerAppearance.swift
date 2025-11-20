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
    var normalThickness: CGFloat = 1.0
    var activeThickness: CGFloat = 1.5
    var normalColor: NSColor = NSColor.separatorColor
    var activeColor: NSColor = NSColor.controlAccentColor
    var hitExpansion: CGFloat = 24
    var isDragging: Bool = false
}
