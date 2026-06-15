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
        if !(scrollView.verticalScroller is PanelVerticalScroller) {
            scrollView.verticalScroller = PanelVerticalScroller()
        }
        scrollView.hasVerticalScroller = ScrollBarConfig.hasVerticalScroller
        scrollView.hasHorizontalScroller = ScrollBarConfig.hasHorizontalScroller
        scrollView.autohidesScrollers = ScrollBarConfig.autohidesScrollers
        scrollView.scrollerStyle = .legacy
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
    }
}

// MARK: - Panel Vertical Scroller

final class PanelVerticalScroller: NSScroller {
    override class func scrollerWidth(
        for controlSize: NSControl.ControlSize,
        scrollerStyle: NSScroller.Style
    ) -> CGFloat {
        ScrollBarConfig.trackWidth
    }

    // MARK: - Draw Knob
    override func drawKnob() {
        let knobRect = rect(for: .knob).insetBy(dx: 1, dy: 1)
        guard knobRect.width > 0, knobRect.height > 0 else { return }
        let radius = min(knobRect.width / 2, 3.5)
        let knobPath = NSBezierPath(roundedRect: knobRect, xRadius: radius, yRadius: radius)
        let gradient = NSGradient(colors: [
            NSColor(calibratedWhite: 0.66, alpha: 1),
            NSColor(calibratedWhite: 0.88, alpha: 1),
            NSColor(calibratedWhite: 0.73, alpha: 1),
        ])
        gradient?.draw(in: knobPath, angle: 0)
        NSColor(calibratedWhite: 0.38, alpha: 0.92).setStroke()
        knobPath.lineWidth = 1
        knobPath.stroke()
        let highlightRect = knobRect.insetBy(dx: 1, dy: 1)
        let highlightRadius = max(0, radius - 1)
        let highlightPath = NSBezierPath(
            roundedRect: highlightRect,
            xRadius: highlightRadius,
            yRadius: highlightRadius
        )
        NSColor.white.withAlphaComponent(0.62).setStroke()
        highlightPath.lineWidth = 0.5
        highlightPath.stroke()
    }

    // MARK: - Draw Knob Slot
    override func drawKnobSlot(in slotRect: NSRect, highlight _: Bool) {
        let trackRect = slotRect.insetBy(dx: 1, dy: 0)
        guard trackRect.width > 0, trackRect.height > 0 else { return }
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 3, yRadius: 3)
        let gradient = NSGradient(
            starting: NSColor(calibratedWhite: 0.94, alpha: 1),
            ending: NSColor(calibratedWhite: 0.99, alpha: 1)
        )
        gradient?.draw(in: trackPath, angle: 0)
        NSColor(calibratedWhite: 0.58, alpha: 0.72).setStroke()
        trackPath.lineWidth = 0.75
        trackPath.stroke()
    }
}
