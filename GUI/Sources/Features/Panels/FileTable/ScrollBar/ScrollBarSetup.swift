// ScrollBarSetup.swift
// MiMiNavigator
//
// Description: NSScrollView configuration helper.
//              Applies ScrollBarConfig settings to AppKit scroll views.

import AppKit
import SwiftUI


// MARK: - ScrollBarSetup

/// Applies ScrollBarConfig to an NSScrollView.
/// Call from NSViewRepresentable.makeNSView() to keep scroll bar setup centralised.
@MainActor
enum ScrollBarSetup {

    /// Configure an NSScrollView with values from ScrollBarConfig.
    static func apply(to scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = ScrollBarConfig.hasVerticalScroller
        scrollView.hasHorizontalScroller = ScrollBarConfig.hasHorizontalScroller
        scrollView.autohidesScrollers = ScrollBarConfig.autohidesScrollers
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
    }
}
