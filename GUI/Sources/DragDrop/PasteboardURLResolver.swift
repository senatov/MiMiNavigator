// PasteboardURLResolver.swift
// MiMiNavigator
//
// Extracted from AppKitDropView.swift on 25.03.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Extract file URLs from NSPasteboard — shared between AppKit drop targets

import AppKit
import FileModelKit


// MARK: - PasteboardURLResolver
/// Extracts deduplicated file URLs from NSPasteboard using three strategies:
/// 1. Individual pasteboardItems (best — one NSDraggingItem per pbItem)
/// 2. NSFilenamesPboardType (Finder multi-file drag, deprecated but reliable)
/// 3. NSURL reader (generic fallback)
enum PasteboardURLResolver {


    static func resolve(from pasteboard: NSPasteboard) -> [URL] {
        var items: [URL] = []
        // strategy 1: individual pasteboard items
        if let pbItems = pasteboard.pasteboardItems {
            for pbItem in pbItems {
                if let data = pbItem.data(forType: .fileURL),
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    items.append(url)
                }
            }
        }
        // strategy 2: NSFilenamesPboardType (deprecated but reliable for Finder)
        if items.isEmpty,
           let paths = pasteboard.propertyList(
               forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
           ) as? [String] {
            items = paths.map { URL(fileURLWithPath: $0) }
        }
        // strategy 3: generic NSURL reader
        if items.isEmpty,
           let urls = pasteboard.readObjects(
               forClasses: [NSURL.self],
               options: [.urlReadingFileURLsOnly: true]
           ) as? [URL] {
            items = urls
        }
        // deduplicate (same file may appear via multiple representations)
        var seen = Set<String>()
        return items.filter { seen.insert($0.path).inserted }
    }
}
