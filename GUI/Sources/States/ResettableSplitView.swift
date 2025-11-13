//
//  ResettableSplitView.swift
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

// MARK: -Custom NSSplitView that intercepts double-clicks on the divider
final class ResettableSplitView: NSSplitView {
    weak var coordinatorRef: SplitViewDoubleClickHandler?
    private static let verboseLogs = true

    // Responder overrides to allow keyboard/focus and modifier event handling
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
        log.debug(#function)
        let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
        let dividerRect = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -3, dy: -6)
        if dividerRect.contains(point) { return self }
        return super.hitTest(point)
    }

    // MARK: -
    override func mouseDown(with event: NSEvent) {
        log.debug(#function)
        // Make sure this view receives key and modifier updates
        self.window?.makeFirstResponder(self)
        let loc = convert(event.locationInWindow, from: nil)
        let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
        let hit = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height).insetBy(dx: -3, dy: -6)
        // Debug print
        log.debug(
            "SV.mouseDown clickCount=\(event.clickCount) loc=\(NSStringFromPoint(loc)) hit=\(NSStringFromRect(hit)) flags=\(event.modifierFlags)"
        )
        // Option + single left click → reset split to 50/50
        if event.clickCount == 1,
            event.type == .leftMouseDown,
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option),
            hit.contains(loc)
        {
            log.debug("SV.option-left inside divider hitbox → reset to 50/50")
            if let coord = coordinatorRef {
                DispatchQueue.main.async { coord.handleDoubleClickFromSplitView(self) }
            }
            return
        }
        // Double click fallback
        if event.clickCount == 2, hit.contains(loc) {
            log.debug("SV.double-click divider → reset to 50/50")
            if let coord = coordinatorRef {
                DispatchQueue.main.async { coord.handleDoubleClickFromSplitView(self) }
            }
            return
        }
        super.mouseDown(with: event)
    }

    // MARK: -
    override func rightMouseDown(with event: NSEvent) {
        log.debug(#function)
        if Self.verboseLogs {
            let locWin = event.locationInWindow
            let locView = convert(locWin, from: nil)
            log.debug(
                "SV.rightMouseDown count=\(event.clickCount) locWin=\(NSStringFromPoint(locWin)) locView=\(NSStringFromPoint(locView))"
            )
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
                DispatchQueue.main.async { coord.handleDoubleClickFromSplitView(self) }
            }
            return
        }
        super.rightMouseDown(with: event)
    }
}
