// KeyboardFocusSupport.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared keyboard focus modifiers for Windows-style Tab navigation.

import SwiftUI

// MARK: - Keyboard focus support
extension View {
    func keyboardFocusSection() -> some View {
        focusSection()
            .focusEffectDisabled(false)
    }

    func keyboardFocusable() -> some View {
        focusable(true)
            .focusEffectDisabled(false)
    }
}
