// DesignTokens.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.10.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Centralized design tokens for consistent UI styling

import AppKit
import SwiftUI

// MARK: - Design Tokens
/// Centralized design constants for maintaining consistent visual appearance.
/// Based on an 8pt grid system.
enum DesignTokens {

    // MARK: - Grid & Spacing
    /// Base grid unit (8pt)
    static let grid: CGFloat = 8

    /// Standard corner radius (HIG: 8pt for cards/panels)
    static let radius: CGFloat = 8

    // MARK: - Semantic Spacing
    enum Spacing {
        static let compact: CGFloat = 4
        static let related: CGFloat = 8
        static let group: CGFloat = 12
        static let section: CGFloat = 16
        static let container: CGFloat = 24
    }

    // MARK: - Semantic Radius
    enum Radius {
        static let control: CGFloat = 7
        static let card: CGFloat = 10
        static let dialog: CGFloat = 12
    }

    // MARK: - Control Metrics
    enum Control {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 6
        static let borderWidth: CGFloat = 0.75
        static let raisedBorderWidth: CGFloat = 1
        static let focusBorderWidth: CGFloat = 1.5
    }

    // MARK: - Dialog Metrics
    enum Dialog {
        static let contentPadding: CGFloat = 24
        static let headerSpacing: CGFloat = 12
        static let footerSpacing: CGFloat = 10
        static let iconSize: CGFloat = 48
        static let standardWidth: CGFloat = 440
    }

    // MARK: - Colors
    /// Card background color (window background)
    static let card = Color(nsColor: .windowBackgroundColor)

    /// Panel background color (control background)
    static let panelBg = Color(nsColor: .controlBackgroundColor)

    /// Warm white background for active panel and session table
    @MainActor static var warmWhite: Color { ColorThemeStore.shared.activeTheme.warmWhite }

    /// Zebra stripe colors — themed, persisted via ColorThemeStore
    @MainActor static var zebraActiveEven: Color { ColorThemeStore.shared.activeTheme.zebraActiveEven }
    @MainActor static var zebraActiveOdd: Color { ColorThemeStore.shared.activeTheme.zebraActiveOdd }
    @MainActor static var zebraInactiveEven: Color { ColorThemeStore.shared.activeTheme.zebraInactiveEven }
    @MainActor static var zebraInactiveOdd: Color { ColorThemeStore.shared.activeTheme.zebraInactiveOdd }

    // MARK: - Row-specific Tokens (Finder-style)
    enum Row {
        /// Icon size - 16pt (Finder list view standard), scaled
        @MainActor static var iconSize: CGFloat { FilePanelStyle.iconSize }
    }
}

// MARK: - Semantic Control State
enum SemanticControlState: Equatable {
    case normal
    case hovered
    case focused
    case pressed
    case selected
    case disabled
    static func resolve(isEnabled: Bool, isPressed: Bool, isSelected: Bool, isFocused: Bool, isHovered: Bool) -> Self {
        if !isEnabled { return .disabled }
        if isPressed { return .pressed }
        if isSelected { return .selected }
        if isFocused { return .focused }
        if isHovered { return .hovered }
        return .normal
    }
}
