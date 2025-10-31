//
//  DividerAppearance.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Appearance carrier
public final class DividerAppearance {
    var normalThickness: CGFloat = 1.5
    var activeThickness: CGFloat = 3.0
    var normalColor: NSColor = NSColor.systemOrange.withAlphaComponent(0.55)
    var activeColor: NSColor = .systemOrange
    var hitExpansion: CGFloat = 24
    var isDragging: Bool = false
}
