// ScrollBarConfig.swift
// MiMiNavigator
//
// Description: Central configuration for scroll bar appearance and behavior.
//              Edit values here to tweak scroll bar look & position across all panels.

import AppKit
import SwiftUI


// MARK: - ScrollBarConfig

/// All scroll bar knobs in one place — tweak & iterate without hunting through views.
enum ScrollBarConfig {

    /// Width of the scrollbar track area (used for jump button column alignment).
    /// Wider than the macOS default for easier targeting and clearer separation.
    static let trackWidth: CGFloat = 23

    /// Compensates the outer grid inset while keeping the track clear of the border stroke.
    static let trailingPadding: CGFloat = 4 - DesignTokens.grid

    /// Whether inactive (unfocused) panels hide their scroll indicators entirely.
    static let hideScrollersOnInactivePanel: Bool = true

    /// Keep the panel scrollbar visible so its position is always discoverable.
    static let autohidesScrollers: Bool = false

    /// NSScrollView: show vertical scroller.
    static let hasVerticalScroller: Bool = true

    /// NSScrollView: show horizontal scroller.
    static let hasHorizontalScroller: Bool = false
}
