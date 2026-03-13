//  DialogColors.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - DialogColors
/// Dynamic dialog colors — driven by ColorThemeStore.
/// When theme changes in Settings → Colors, all dialogs update immediately.
@MainActor
enum DialogColors {
    /// Section headers, card backgrounds
    static var light: Color {
        let s = ColorThemeStore.shared
        if !s.hexDialogBase.isEmpty, let c = Color(hex: s.hexDialogBase) {
            return c.opacity(1.03)
        }
        return s.activeTheme.dialogBase.blended(with: .white, fraction: 0.35)
    }
    /// Main dialog/panel background
    static var base: Color {
        let s = ColorThemeStore.shared
        if !s.hexDialogBase.isEmpty, let c = Color(hex: s.hexDialogBase) {
            return c
        }
        return s.activeTheme.dialogBase
    }
    /// Contrast stripes, header/footer bars
    static var stripe: Color {
        let s = ColorThemeStore.shared
        if !s.hexDialogStripe.isEmpty, let c = Color(hex: s.hexDialogStripe) {
            return c
        }
        return s.activeTheme.dialogStripe
    }
    /// Separator / border color for dialogs
    static var border: Color {
        let s = ColorThemeStore.shared
        if !s.hexSeparator.isEmpty, let c = Color(hex: s.hexSeparator) {
            return c
        }
        return s.activeTheme.separatorColor
    }
    /// Accent color for buttons and highlights
    static var accent: Color {
        let s = ColorThemeStore.shared
        if !s.hexAccent.isEmpty, let c = Color(hex: s.hexAccent) {
            return c
        }
        return s.activeTheme.accentColor
    }
}
