//
// CustomSplitView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Custom NSSplitView drawing a colored divider
public final class CustomSplitView: NSSplitView {
    let appearanceProxy = DividerAppearance()

    // Callback invoked when user requests a 50/50 reset (wired<-OrangeSplitView.Coordinator)
    public var onDividerReset: ((CustomSplitView) -> Void)?

    // Ensure we can receive modifier key changes and precise mouse events
    public override var acceptsFirstResponder: Bool { true }
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        log.debug("CSV.viewDidMoveToWindow onDividerReset is nil? \(onDividerReset == nil)")
    }

    // MARK: -
    public override var dividerThickness: CGFloat {
        appearanceProxy.isDragging ? appearanceProxy.activeThickness : appearanceProxy.normalThickness
    }

    // MARK: -
    private func dividerRect(expandBy dx: CGFloat? = nil, dy: CGFloat = 0) -> NSRect {
        let leftMaxX = arrangedSubviews.first?.frame.maxX ?? 0
        let drawn = NSRect(x: leftMaxX, y: 0, width: dividerThickness, height: bounds.height)
        let expand = dx ?? appearanceProxy.hitExpansion
        return drawn.insetBy(dx: -expand, dy: -dy)
    }

    // MARK: -
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let rect = dividerRect()
        if rect.contains(point) { return self }
        return super.hitTest(point)
    }

    // MARK: -
    public override func flagsChanged(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        log.debug("CSV.flagsChanged flags=\(flags.rawValue) option=\(flags.contains(.option))")
        super.flagsChanged(with: event)
    }

    // MARK: - Capture focus so flagsChanged/drag state are visible
    public override func mouseDown(with event: NSEvent) {
        log.debug("CSV.mouseDown fired clicks=\(event.clickCount) flags=\(event.modifierFlags.rawValue)")
        window?.makeFirstResponder(self)
        let loc = convert(event.locationInWindow, from: nil)
        log.debug("CSV.hitTest loc=\(loc.x),\(loc.y) rect=\(dividerRect())")
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let opt = flags.contains(.option) || NSEvent.modifierFlags.contains(.option)
        let rect = dividerRect()
        let onDivider = rect.contains(loc)
        log.debug("CSV.mouseDown type=\(event.type) count=\(event.clickCount) flags=\(flags) opt=\(opt) onDivider=\(onDivider) hitRect=\(NSStringFromRect(rect))")
        // Option + single left click on divider → ask for 50/50 reset
        if event.clickCount == 1,
           opt,
           onDivider
        {
            log.debug("CSV.option-left on divider → request reset 50/50")
            onDividerReset?(self)
            return
        }
        // Fallback: double-left on divider → also request reset
        if event.clickCount == 2, onDivider {
            log.debug("CSV.double-left on divider → request reset 50/50")
            onDividerReset?(self)
            return
        }
        super.mouseDown(with: event)
    }

    // MARK: -
    public override func drawDivider(in rect: NSRect) {
        log.debug(#function)
        let color = appearanceProxy.isDragging ? appearanceProxy.activeColor : appearanceProxy.normalColor
        color.setFill()
        rect.fill()
    }

    // MARK: -
    public func invalidateDivider() {
        setNeedsDisplay(bounds)
    }
}
