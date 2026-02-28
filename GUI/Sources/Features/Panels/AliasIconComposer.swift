// AliasIconComposer.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Composites a tinted base icon + orange arrow badge for symlinks.

import AppKit

// MARK: - Alias Icon Composer

/// Renders a symlink icon: base icon tinted deep blue + orange arrow in bottom-left corner.
/// Visually distinguishes symlinks from regular directories at a glance.
enum AliasIconComposer {

    // MARK: - Cache

    @MainActor
    private static let cache = NSCache<NSString, NSImage>()

    // MARK: - Public

    @MainActor
    static func compose(symlinkURL url: URL, size: NSSize) -> NSImage {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let result = draw(symlinkURL: url, size: size)
        cache.setObject(result, forKey: key)
        return result
    }

    // MARK: - Private

    @MainActor
    private static func draw(symlinkURL url: URL, size: NSSize) -> NSImage {
        let workspace = NSWorkspace.shared
        let targetURL = url.resolvingSymlinksInPath()
        let base = workspace.icon(forFile: targetURL.path)
        base.size = size

        let composite = NSImage(size: size)
        composite.lockFocus()

        // Step 1: draw base icon tinted deep blue
        base.draw(in: NSRect(origin: .zero, size: size))
        NSColor(#colorLiteral(red: 0.05, green: 0.18, blue: 0.52, alpha: 0.28)).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        // Step 2: orange arrow badge in bottom-left (~38% of icon size)
        let badgeLen = size.width * 0.62
        let badgeRect = NSRect(x: 1, y: 1, width: badgeLen, height: badgeLen)
        drawArrow(in: badgeRect)

        composite.unlockFocus()
        return composite
    }

    /// Two-pass arrow: white outline first, then orange arrow on top.
    private static func drawArrow(in rect: NSRect) {
        guard let img = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil)
        else { return }
        // White outline pass (slightly larger)
        let outlineRect = rect.insetBy(dx: -1.5, dy: -1.5)
        let outlineCfg = NSImage.SymbolConfiguration(pointSize: outlineRect.width, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        let outline = img.withSymbolConfiguration(outlineCfg) ?? img
        outline.draw(in: outlineRect, from: .zero, operation: .sourceOver, fraction: 0.90)
        // Orange arrow
        let arrowCfg = NSImage.SymbolConfiguration(pointSize: rect.width, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [
                NSColor(#colorLiteral(red: 1.0, green: 0.92, blue: 0.0, alpha: 1.0))
            ]))
        let arrow = img.withSymbolConfiguration(arrowCfg) ?? img
        arrow.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
}
