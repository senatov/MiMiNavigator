// DragDropTargetResolver.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Defines stable destination priority for panel drag-and-drop.

import Foundation

// MARK: - DragDropTargetResolver
enum DragDropTargetResolver {
    // MARK: - Preferred Explicit Target
    static func preferredExplicitTarget(parent: URL?, directory: URL?) -> URL? {
        parent ?? directory
    }
}
