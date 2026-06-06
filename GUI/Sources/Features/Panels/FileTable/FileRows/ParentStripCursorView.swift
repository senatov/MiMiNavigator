// ParentStripCursorView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.06.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppKit cursor rect and hover tracking for the parent-navigation strip.

import AppKit
import SwiftUI

// MARK: - ParentStripCursorView
struct ParentStripCursorView: NSViewRepresentable {
    @Binding var isHovering: Bool
    func makeNSView(context: Context) -> ParentStripCursorNSView {
        let view = ParentStripCursorNSView()
        view.onHoverChange = { hovering in
            isHovering = hovering
        }
        return view
    }
    func updateNSView(_ nsView: ParentStripCursorNSView, context: Context) {
        nsView.onHoverChange = { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - ParentStripCursorNSView
final class ParentStripCursorNSView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    private var trackingAreaToken: NSTrackingArea?
    private static let navigateUpCursor: NSCursor = {
        guard let image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Navigate up") else {
            return .pointingHand
        }
        image.size = NSSize(width: 18, height: 18)
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
    }()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = false
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaToken {
            removeTrackingArea(trackingAreaToken)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaToken = area
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: Self.navigateUpCursor)
    }
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        withAnimation(.easeInOut(duration: 0.10)) {
            onHoverChange?(true)
        }
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        withAnimation(.easeInOut(duration: 0.10)) {
            onHoverChange?(false)
        }
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
