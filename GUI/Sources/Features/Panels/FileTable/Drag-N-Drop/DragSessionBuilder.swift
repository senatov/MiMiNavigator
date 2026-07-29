// DragSessionBuilder.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 16.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Creates NSDraggingItem array for AppKit drag sessions

import AppKit
import SwiftUI

// MARK: - DragSessionBuilder
struct DragSessionBuilder {

    /// Create dragging items positioned at the mouse location.
    /// `mouseLocation` is in the source view's coordinate system.
    static func makeDraggingItems(from urls: [URL], at mouseLocation: NSPoint) -> [NSDraggingItem] {
        guard !urls.isEmpty else { return [] }
        return urls.enumerated().map { index, fileURL in
            let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
            let itemCount = index == 0 ? urls.count : 1
            let preview = makePreviewImage(firstURL: fileURL, itemCount: itemCount, isContact: false)
            item.setDraggingFrame(draggingFrame(for: preview.size, at: mouseLocation), contents: preview)
            return item
        }
    }

    // MARK: - Preview Image
    static func makePreviewImage(firstURL: URL, itemCount: Int, isContact: Bool) -> NSImage {
        let size = NSSize(width: itemCount > 1 ? 58 : 42, height: 42)
        let image = NSImage(size: size, flipped: false) { rect in
            drawPreviewBackground(in: rect, isContact: isContact)
            drawIcon(for: firstURL, in: size)
            if itemCount > 1 {
                drawCountBadge(itemCount, in: size, isContact: isContact)
            }
            if isContact {
                drawContactBadge(in: size)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Preview Background
    private static func drawPreviewBackground(in rect: NSRect, isContact: Bool) {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11)
        let fillColor = isContact
            ? NSColor(#colorLiteral(red: 0.18, green: 0.28, blue: 0.42, alpha: 1))
            : NSColor.windowBackgroundColor
        fillColor.withAlphaComponent(isContact ? 0.88 : 0.82).setFill()
        path.fill()
        if isContact {
            NSGraphicsContext.current?.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(#colorLiteral(red: 0.20, green: 0.34, blue: 0.55, alpha: 0.62))
            shadow.shadowBlurRadius = 5
            shadow.set()
            NSColor(#colorLiteral(red: 0.42, green: 0.58, blue: 0.78, alpha: 0.82)).setStroke()
            path.lineWidth = 3
            path.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()
        }
        let borderColor = isContact ? NSColor.white : NSColor.separatorColor
        borderColor.withAlphaComponent(isContact ? 0.98 : 0.55).setStroke()
        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 8, yRadius: 8)
        border.lineWidth = isContact ? 2 : 1
        border.stroke()
    }

    // MARK: - Icon
    private static func drawIcon(for url: URL, in size: NSSize) {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 26, height: 26)
        icon.draw(in: NSRect(x: 8, y: 8, width: 26, height: 26))
    }

    // MARK: - Count Badge
    private static func drawCountBadge(_ count: Int, in size: NSSize, isContact: Bool) {
        let text = count > 999 ? "999+" : "\(count)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let badgeWidth = max(22, ceil(textSize.width) + 10)
        let badgeRect = NSRect(
            x: size.width - badgeWidth - 5,
            y: size.height - 21,
            width: badgeWidth,
            height: 17
        )
        (isContact ? NSColor.systemGreen : NSColor.systemRed).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 8.5, yRadius: 8.5).fill()
        let textRect = NSRect(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }

    // MARK: - Contact Badge
    private static func drawContactBadge(in size: NSSize) {
        let badgeRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        let symbol = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        symbol?.draw(in: badgeRect.insetBy(dx: 3, dy: 3))
    }

    // MARK: - Dragging Frames
    private static func draggingFrame(for size: NSSize, at mouseLocation: NSPoint) -> NSRect {
        NSRect(
            x: mouseLocation.x - size.width / 2,
            y: mouseLocation.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

}
