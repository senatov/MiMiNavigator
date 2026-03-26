// OSHiddenIconComposer.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 26.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Composites base folder icon + eye.slash badge for macOS UF_HIDDEN dirs
//   (~/Library, .Spotlight-V100 etc.) — items hidden by OS flag, not by dot-prefix.

import AppKit

// MARK: - OS Hidden Icon Composer

/// Renders OS-hidden directory icon: base folder + translucent eye.slash badge in bottom-left.
/// Visually tells user "this dir is hidden by macOS, not just dot-named".
enum OSHiddenIconComposer {

    // MARK: - Cache

    @MainActor
    private static let cache = NSCache<NSString, NSImage>()


    // MARK: - Public

    @MainActor
    static func compose(url: URL, size: NSSize) -> NSImage {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let result = draw(url: url, size: size)
        cache.setObject(result, forKey: key)
        return result
    }


    // MARK: - Private

    @MainActor
    private static func draw(url: URL, size: NSSize) -> NSImage {
        let base = NSWorkspace.shared.icon(forFile: url.path)
        base.size = size
        let composite = NSImage(size: size)
        composite.lockFocus()
        // base folder icon — slightly dimmed to hint "hidden"
        base.draw(in: NSRect(origin: .zero, size: size))
        NSColor(white: 0.35, alpha: 0.18).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        // eye.slash badge bottom-left (~45% of icon)
        let badgeLen = size.width * 0.50
        let badgeRect = NSRect(x: 1, y: 1, width: badgeLen, height: badgeLen)
        drawEyeBadge(in: badgeRect)
        composite.unlockFocus()
        return composite
    }


    /// Two-pass eye.slash: white outline first, then colored icon on top.
    private static func drawEyeBadge(in rect: NSRect) {
        guard let img = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: "OS hidden")
        else { return }
        // white outline pass
        let outlineRect = rect.insetBy(dx: -1.2, dy: -1.2)
        let outlineCfg = NSImage.SymbolConfiguration(pointSize: outlineRect.width, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        let outline = img.withSymbolConfiguration(outlineCfg) ?? img
        outline.draw(in: outlineRect, from: .zero, operation: .sourceOver, fraction: 0.85)
        // main badge — muted violet to distinguish from orange symlink arrow
        let badgeCfg = NSImage.SymbolConfiguration(pointSize: rect.width, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [
                NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.78, alpha: 0.92)
            ]))
        let badge = img.withSymbolConfiguration(badgeCfg) ?? img
        badge.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
}
