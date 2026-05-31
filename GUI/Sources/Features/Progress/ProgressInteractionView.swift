// ProgressInteractionView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Mouse interaction capture views for ProgressPanel.

import AppKit

// MARK: - ProgressInteractionView

final class ProgressInteractionView: NSView {
    var onInteraction: (() -> Void)?

    // MARK: - Update Tracking Areas
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    // MARK: - First Mouse
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        onInteraction?()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        onInteraction?()
        super.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onInteraction?()
        super.rightMouseDown(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        onInteraction?()
        super.rightMouseDragged(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        onInteraction?()
        super.otherMouseDown(with: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        super.otherMouseUp(with: event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        onInteraction?()
        super.otherMouseDragged(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        onInteraction?()
        super.scrollWheel(with: event)
    }
}

// MARK: - ProgressInteractionEffectView

final class ProgressInteractionEffectView: NSVisualEffectView {
    var onInteraction: (() -> Void)?

    // MARK: - Update Tracking Areas
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    // MARK: - First Mouse
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        onInteraction?()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        onInteraction?()
        super.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onInteraction?()
        super.rightMouseDown(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        onInteraction?()
        super.rightMouseDragged(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        onInteraction?()
        super.otherMouseDown(with: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        super.otherMouseUp(with: event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        onInteraction?()
        super.otherMouseDragged(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        onInteraction?()
        super.scrollWheel(with: event)
    }
}
