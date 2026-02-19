//
// ResettableSplitView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.11.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

@MainActor
protocol SplitViewDoubleClickHandler: AnyObject {
    func handleDoubleClickFromSplitView(_ sv: NSSplitView)
}

// MARK: - Custom NSSplitView that intercepts double-clicks on the divider
final class ResettableSplitView: NSSplitView {
    weak var coordinatorRef: SplitViewDoubleClickHandler?
    private static let verboseLogs = true

    // Divider visual states
    var isDragging: Bool = false { didSet { setNeedsDisplay(bounds) } }
    var isHovered: Bool = false  { didSet { setNeedsDisplay(bounds) } }

    // Tracking area for hover detection
    private var trackingArea: NSTrackingArea?

    // MARK: - Divider thickness: thin in passive, slightly wider on hover/drag
    override var dividerThickness: CGFloat {
        isDragging ? 3.0 : (isHovered ? 2.0 : 1.5)
    }

    // MARK: - Divider color:
    //   passive  → pale orange
    //   hover    → pale blue
    //   dragging → red-orange
    override func drawDivider(in rect: NSRect) {
        let color: NSColor
        if isDragging {
            color = #colorLiteral(red: 0.95, green: 0.38, blue: 0.10, alpha: 0.90)
        } else if isHovered {
            color = #colorLiteral(red: 0.45, green: 0.72, blue: 1.00, alpha: 0.85)
        } else {
            color = #colorLiteral(red: 1.00, green: 0.70, blue: 0.40, alpha: 0.45)
        }
        color.setFill()
        rect.fill()
    }

    // MARK: - Tracking area lifecycle
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    // MARK: - Hover detection
    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
        let hoverRect = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -6, dy: 0)
        let hovering = hoverRect.contains(loc)
        if hovering != isHovered { isHovered = hovering }
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        super.mouseExited(with: event)
    }

    // Responder overrides -> allow keyboard/focus+modifier event handling
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    // MARK: -
    override func viewDidMoveToWindow() {
        log.debug(#function)
        super.viewDidMoveToWindow()
        self.window?.acceptsMouseMovedEvents = true
    }

    // MARK: -
    override func hitTest(_ point: NSPoint) -> NSView? {
        let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
        let dividerRect = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -3, dy: -6)
        if dividerRect.contains(point) { return self }
        return super.hitTest(point)
    }

    // MARK: -
    override func mouseDown(with event: NSEvent) {
        log.debug(#function)
        self.window?.makeFirstResponder(self)
        let loc = convert(event.locationInWindow, from: nil)
        let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
        let hit = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -3, dy: -6)
        log.debug("SV.mouseDown clickCount=\(event.clickCount) loc=\(NSStringFromPoint(loc)) hit=\(NSStringFromRect(hit)) flags=\(event.modifierFlags)")
        if event.clickCount == 1,
            event.type == .leftMouseDown,
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option),
            hit.contains(loc)
        {
            log.debug("SV.option-left inside divider hitbox → reset to 50/50")
            if let coord = coordinatorRef {
                Task { @MainActor in coord.handleDoubleClickFromSplitView(self) }
            }
            return
        }
        if event.clickCount == 2, hit.contains(loc) {
            log.debug("SV.double-click divider → reset to 50/50")
            if let coord = coordinatorRef {
                Task { @MainActor in coord.handleDoubleClickFromSplitView(self) }
            }
            return
        }
        super.mouseDown(with: event)
    }

    // MARK: - Drag state for divider color
    override func mouseDragged(with event: NSEvent) {
        isDragging = true
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        super.mouseUp(with: event)
    }

    // MARK: -
    override func rightMouseDown(with event: NSEvent) {
        log.debug(#function)
        if Self.verboseLogs {
            let locWin = event.locationInWindow
            let locView = convert(locWin, from: nil)
            log.debug("SV.rightMouseDown count=\(event.clickCount) locWin=\(NSStringFromPoint(locWin)) locView=\(NSStringFromPoint(locView))")
        }
        let loc = convert(event.locationInWindow, from: nil)
        let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
        let hit = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -3, dy: -6)
        if Self.verboseLogs {
            log.debug("SV.right? loc=\(NSStringFromPoint(loc)) hit=\(NSStringFromRect(hit))")
        }
        if hit.contains(loc) {
            if Self.verboseLogs {
                log.debug("SV.right → inside divider hitbox, forwarding to coordinator")
            }
            if let coord = coordinatorRef {
                Task { @MainActor in coord.handleDoubleClickFromSplitView(self) }
            }
            return
        }
        super.rightMouseDown(with: event)
    }
}
