    //
    //  DragSessionBuilder.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 16.03.2026.
    //  Copyright © 2026 Senatov. All rights reserved.
    //

    import AppKit
    import FileModelKit
    import SwiftUI

    struct DragSessionBuilder {
        static func makeDraggingItems(from urls: [URL]) -> [NSDraggingItem] {
            urls.map { fileURL in
                let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)

                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                icon.size = NSSize(width: 32, height: 32)

                let frame = NSRect(origin: .zero, size: icon.size)
                item.setDraggingFrame(frame, contents: icon)

                return item
            }
        }
    }
