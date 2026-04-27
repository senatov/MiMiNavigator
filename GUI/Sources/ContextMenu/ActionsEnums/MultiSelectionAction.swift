// MultiSelectionAction.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Context actions available for multiple selected files/directories

import Foundation

// MARK: - Multi Selection Action
/// Actions available when multiple files/directories are selected (marked)
enum MultiSelectionAction: String, CaseIterable, Identifiable {
    // Clipboard
    case cut
    case copy
    case copyAsPathname
    case paste

    // Operations
    case compress
    case share

    // Navigation
    case revealInFinder
    case console

    // Danger zone
    case delete

    // Cross-panel
    case mirrorPanel

    // Favorites
    case addToFavorites

    var id: String { rawValue }

    /// Human-readable title for each action
    var title: String {
        switch self {
        case .cut: return "Cut"
        case .copy: return "Copy"
        case .copyAsPathname: return "Copy as Pathname"
        case .paste: return "Paste"
        case .compress: return "Compress"
        case .share: return "Share..."
        case .revealInFinder: return "Show in Finder"
        case .console: return "Console"
        case .delete: return "Move to Trash"
        case .mirrorPanel: return "Mirror Panel"
        case .addToFavorites: return "Add to Favorites"
        }
    }

    /// SF Symbol icon
    var systemImage: String {
        switch self {
        case .cut: return "scissors"
        case .copy: return "doc.on.doc"
        case .copyAsPathname: return "link.circle.fill"
        case .paste: return "doc.on.clipboard"
        case .compress: return "archivebox"
        case .share: return "square.and.arrow.up"
        case .revealInFinder: return "folder"
        case .console: return "terminal"
        case .delete: return "trash"
        case .mirrorPanel: return "arrow.left.arrow.right.square"
        case .addToFavorites: return "star.fill"
        }
    }

    /// Keyboard shortcut hint
    var shortcutHint: String? {
        switch self {
        case .cut: return "⌘X"
        case .copy: return "⌘C"
        case .copyAsPathname: return "⌥⌘C"
        case .paste: return "⌘V"
        case .delete: return "⌘⌫"
        case .mirrorPanel: return "⌘="
        default: return nil
        }
    }
}
