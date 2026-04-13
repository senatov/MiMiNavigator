// DragSessionBuilder.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 16.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Creates NSDraggingItem array for AppKit drag sessions

import AppKit
import FileModelKit
import SwiftUI

// MARK: - DragSessionBuilder
struct DragSessionBuilder {

    /// Create dragging items positioned at the mouse location.
    /// `mouseLocation` is in the source view's coordinate system.
    static func makeDraggingItems(from urls: [URL], at mouseLocation: NSPoint) -> [NSDraggingItem] {
        let iconSize = NSSize(width: 32, height: 32)
        return urls.enumerated()
            .map { index, fileURL in
                let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                icon.size = iconSize
                // Stack icons with slight offset for multi-file drag
                let offset = CGFloat(index) * 4
                let origin = NSPoint(
                    x: mouseLocation.x - iconSize.width / 2 + offset,
                    y: mouseLocation.y - iconSize.height / 2 - offset
                )
                item.setDraggingFrame(NSRect(origin: origin, size: iconSize), contents: icon)
                return item
            }
    }
}
