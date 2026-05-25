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
        guard let firstURL = urls.first else { return [] }
        let previewImage = makePreviewImage(firstURL: firstURL, itemCount: urls.count)
        let previewFrame = draggingFrame(for: previewImage.size, at: mouseLocation)
        let hiddenImage = makeHiddenImage()
        return urls.enumerated().map { index, fileURL in
            let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
            if index == 0 {
                item.setDraggingFrame(previewFrame, contents: previewImage)
            } else {
                item.setDraggingFrame(hiddenDraggingFrame(at: mouseLocation), contents: hiddenImage)
            }
            return item
        }
    }

    // MARK: - Preview Image
    private static func makePreviewImage(firstURL: URL, itemCount: Int) -> NSImage {
        let size = NSSize(width: itemCount > 1 ? 58 : 42, height: 42)
        let image = NSImage(size: size)
        image.lockFocus()
        drawPreviewBackground(in: NSRect(origin: .zero, size: size))
        drawIcon(for: firstURL, in: size)
        if itemCount > 1 {
            drawCountBadge(itemCount, in: size)
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: - Preview Background
    private static func drawPreviewBackground(in rect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.82).setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 9, yRadius: 9).fill()
        NSColor.separatorColor.withAlphaComponent(0.55).setStroke()
        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()
    }

    // MARK: - Icon
    private static func drawIcon(for url: URL, in size: NSSize) {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 26, height: 26)
        icon.draw(in: NSRect(x: 8, y: 8, width: 26, height: 26))
    }

    // MARK: - Count Badge
    private static func drawCountBadge(_ count: Int, in size: NSSize) {
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
        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 8.5, yRadius: 8.5).fill()
        let textRect = NSRect(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)
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

    private static func hiddenDraggingFrame(at mouseLocation: NSPoint) -> NSRect {
        NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
    }

    // MARK: - Hidden Image
    private static func makeHiddenImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        return image
    }
}
