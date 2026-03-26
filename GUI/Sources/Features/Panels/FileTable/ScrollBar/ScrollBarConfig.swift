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
    /// macOS system default ~15pt; increase to give more breathing room.
    static let trackWidth: CGFloat = 15

    /// Right-side padding of the file panel content area.
    /// Controls how close the scrollbar sits to the panel edge.
    /// 0 = flush, 1 = 1pt gap (default), negative = overlap.
    static let trailingPadding: CGFloat = 1

    /// Whether inactive (unfocused) panels hide their scroll indicators entirely.
    static let hideScrollersOnInactivePanel: Bool = true

    /// NSScrollView: auto-hide scrollers when not scrolling.
    static let autohidesScrollers: Bool = true

    /// NSScrollView: show vertical scroller.
    static let hasVerticalScroller: Bool = true

    /// NSScrollView: show horizontal scroller.
    static let hasHorizontalScroller: Bool = false
}
