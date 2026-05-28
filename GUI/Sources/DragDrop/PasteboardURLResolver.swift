// PasteboardURLResolver.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Extract file URLs from NSPasteboard for AppKit drop targets

import AppKit

// MARK: - PasteboardURLResolver
/// Extracts deduplicated file URLs from NSPasteboard.
enum PasteboardURLResolver {
    private static let nsURLPasteboardType = NSPasteboard.PasteboardType("NSURLPboardType")
    private static let nsFilenamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    static let fileURLPasteboardTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        NSPasteboard.PasteboardType("public.file-url"),
        nsURLPasteboardType,
        nsFilenamesPasteboardType
    ]

    // MARK: - Resolve
    static func resolve(from pasteboard: NSPasteboard) -> [URL] {
        var items: [URL] = []
        if let pbItems = pasteboard.pasteboardItems {
            for pbItem in pbItems {
                if let data = pbItem.data(forType: .fileURL),
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    items.append(url)
                }
                if let data = pbItem.data(forType: .URL),
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   url.isFileURL {
                    items.append(url)
                }
                if let data = pbItem.data(forType: nsURLPasteboardType),
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   url.isFileURL {
                    items.append(url)
                }
            }
        }
        if items.isEmpty,
           let paths = pasteboard.propertyList(
               forType: nsFilenamesPasteboardType
           ) as? [String] {
            items = paths.map { URL(fileURLWithPath: $0) }
        }
        if items.isEmpty,
           let urls = pasteboard.readObjects(
               forClasses: [NSURL.self],
               options: [.urlReadingFileURLsOnly: true]
           ) as? [URL] {
            items = urls
        }
        var seen = Set<String>()
        return items.filter { seen.insert($0.path).inserted }
    }
}
