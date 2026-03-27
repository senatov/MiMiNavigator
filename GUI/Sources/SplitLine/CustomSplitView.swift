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
        // Enable layer-backed rendering so drawDivider shadow isn't clipped by view bounds
        wantsLayer = true
        layer?.masksToBounds = false
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

    // MARK: - 3D divider with gradient and drop-shadows (Total Commander chrome style)
    public override func drawDivider(in rect: NSRect) {
        let isDrag = appearanceProxy.isDragging
        let baseColor = isDrag ? appearanceProxy.activeColor : appearanceProxy.normalColor
        NSGraphicsContext.saveGraphicsState()

        // ── Body gradient  (light top edge → base → dark bottom edge)
        let grad = NSGradient(colors: [
            baseColor.highlight(withLevel: 0.45) ?? baseColor,   // bright highlight
            baseColor,                                             // mid base
            baseColor.shadow(withLevel: 0.30) ?? baseColor,      // dark shadow side
        ]) ?? NSGradient(starting: baseColor, ending: baseColor)!

        let bodyPath = NSBezierPath(rect: rect)
        grad.draw(in: bodyPath, angle: 0)   // horizontal gradient: left=light, right=dark

        // ── Left specular edge (1px bright line)
        NSColor.white.withAlphaComponent(isDrag ? 0.55 : 0.35).setFill()
        NSRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height).fill()

        // ── Right shadow edge (1px dark line)
        (baseColor.shadow(withLevel: isDrag ? 0.50 : 0.35) ?? NSColor.black.withAlphaComponent(0.3)).setFill()
        NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()

        // ── Drop shadow: soft dark band just to the right of the divider
        let shadowColor = NSColor.black.withAlphaComponent(isDrag ? 0.22 : 0.12)
        let shadowRect = NSRect(x: rect.maxX, y: rect.minY, width: 3, height: rect.height)
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = NSSize(width: 2, height: 0)
        shadow.set()
        shadowColor.withAlphaComponent(0.0).setFill()   // invisible fill — shadow only
        NSBezierPath(rect: shadowRect).fill()

        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: -
    public func invalidateDivider() {
        setNeedsDisplay(bounds)
    }
}
