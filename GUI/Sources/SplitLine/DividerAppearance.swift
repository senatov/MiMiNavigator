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
    var normalColor: NSColor = #colorLiteral(red: 0.55, green: 0.55, blue: 0.60, alpha: 1.0)
    var activeColor: NSColor = #colorLiteral(red: 1.0, green: 0.3, blue: 0.0, alpha: 1.0)
    var hitExpansion: CGFloat = 24
    var isDragging: Bool = false
}
