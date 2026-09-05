// FileRecycleService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Finder-compatible recycling for local and File Provider items.

import AppKit
import Foundation

// MARK: - File Recycle Service

@MainActor
enum FileRecycleService {
    // MARK: - Recycle Item
    static func recycle(_ url: URL) async throws -> URL? {
        let recycledURLs = try await NSWorkspace.shared.recycle([url])
        return recycledURLs[url]
    }
}
