// DragDropTargetResolver.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Defines stable destination priority for panel drag-and-drop.

import Foundation

// MARK: - DragDropTargetResolver
enum DragDropTargetResolver {
    // MARK: - Parent Destination
    static func parentDestination(currentURL: URL, archiveURLAtRoot: URL? = nil) -> URL? {
        let sourceURL = archiveURLAtRoot ?? currentURL
        guard sourceURL.path != "/" else { return nil }
        return sourceURL.deletingLastPathComponent()
    }

    // MARK: - Preferred Explicit Target
    static func preferredExplicitTarget(parent: URL?, directory: URL?) -> URL? {
        parent ?? directory
    }
}
