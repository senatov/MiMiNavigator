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

    /// Compact scrollbar track width, also used to align the jump button column.
    static let trackWidth: CGFloat = 15

    static let jumpButtonHeight: CGFloat = 14
    static let jumpButtonOuterPadding: CGFloat = 2
    static let jumpButtonTrackGap: CGFloat = 1

    /// Leaves the native track clear of the jump-to-edge button at each end.
    static let jumpButtonTrackInset: CGFloat =
        jumpButtonOuterPadding + jumpButtonHeight + jumpButtonTrackGap

    /// Pulls the compact track toward the panel edge while retaining a small border clearance.
    static let trailingPadding: CGFloat = 2 - DesignTokens.grid / 2

    /// Whether inactive (unfocused) panels hide their scroll indicators entirely.
    static let hideScrollersOnInactivePanel: Bool = true

    /// Hide the track when all rows fit, regardless of the system scroller style.
    static let autohidesScrollers: Bool = true

    /// NSScrollView: show horizontal scroller.
    static let hasHorizontalScroller: Bool = false
}
