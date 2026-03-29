//
//  File.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backward compatibility bridge
extension FileRowView {
    /// Legacy API — redirects to NSWorkspace
    @MainActor
    static func getSmartIcon(for file: CustomFile) -> NSImage {
        let img = NSWorkspace.shared.icon(forFile: file.urlValue.path)
        img.size = NSSize(width: 128, height: 128)
        return img
    }

    /// Legacy API — NSWorkspace fallback (avoid SmartIconService overload ambiguity)
    @MainActor
    static func getSmartIcon(for url: URL, size: NSSize = NSSize(width: 128, height: 128)) -> NSImage {
        let img = NSWorkspace.shared.icon(forFile: url.path)
        img.size = size
        return img
    }
}
