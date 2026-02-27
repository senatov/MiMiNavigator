// AliasIconComposer.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Composites a Finder-style alias arrow onto a base icon.

import AppKit

// MARK: - Alias Icon Composer

/// Draws the classic macOS Finder alias arrow (curved arrow, white drop-shadow)
/// in the bottom-left corner of a base icon — exactly as Finder renders aliases.
enum AliasIconComposer {

    // MARK: - Public

    /// Returns a new NSImage = base icon + Finder alias arrow overlay.
    /// Result is cached by base-image pointer to avoid re-drawing on every row render.
    @MainActor
    static func compose(base: NSImage, size: NSSize) -> NSImage {
        if let cached = cache.object(forKey: CacheKey(base)) { return cached }
        let result = draw(base: base, size: size)
        cache.setObject(result, forKey: CacheKey(base))
        return result
    }

    // MARK: - Private

    @MainActor
    private static let cache = NSCache<CacheKey, NSImage>()

    @MainActor
    private static func draw(base: NSImage, size: NSSize) -> NSImage {
        let composite = NSImage(size: size)
        composite.lockFocus()
        // Draw base icon
        base.draw(in: NSRect(origin: .zero, size: size))
        // Arrow badge occupies bottom-left ~40% of icon
        let arrowSize = NSSize(width: size.width * 0.40, height: size.height * 0.40)
        let arrowRect = NSRect(origin: NSPoint(x: 1, y: 1), size: arrowSize)
        drawFinderArrow(in: arrowRect)
        composite.unlockFocus()
        return composite
    }

    /// Draws a curved arrow matching the Finder alias badge:
    /// white rounded-rect badge + blue SF Symbol arrow.
    private static func drawFinderArrow(in rect: NSRect) {
        // White badge for contrast on any icon colour
        let badge = NSBezierPath(
            roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
            xRadius: rect.width * 0.18,
            yRadius: rect.height * 0.18
        )
        NSColor.white.withAlphaComponent(0.88).setFill()
        badge.fill()
        NSColor(white: 0.55, alpha: 0.6).setStroke()
        badge.lineWidth = 0.5
        badge.stroke()
        // Blue arrow symbol inside badge
        guard let arrowImg = NSImage(systemSymbolName: "arrow.up.right",
                                     accessibilityDescription: nil) else { return }
        let padding = rect.width * 0.20
        let imgRect = rect.insetBy(dx: padding, dy: padding)
        let cfg = NSImage.SymbolConfiguration(pointSize: imgRect.width, weight: .medium)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor:
                NSColor(red: 0.12, green: 0.36, blue: 0.85, alpha: 1.0)))
        let colored = arrowImg.withSymbolConfiguration(cfg) ?? arrowImg
        colored.draw(in: imgRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    // MARK: - NSCache key wrapping NSImage pointer identity

    private final class CacheKey: NSObject {
        let ptr: ObjectIdentifier
        init(_ img: NSImage) { ptr = ObjectIdentifier(img) }
        override var hash: Int { ptr.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            (object as? CacheKey)?.ptr == ptr
        }
    }
}
