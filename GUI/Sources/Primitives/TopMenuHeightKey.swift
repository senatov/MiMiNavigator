//
//  TopMenuHeightKey.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.11.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// PrefKey for measuring TopMenuBarView height
struct TopMenuHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
