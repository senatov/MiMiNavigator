// FileAction.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.10.2025.
// Refactored: 04.02.2026
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Context actions for files - aligned with Finder standards

import Foundation

/// Represents context actions available for a regular file.
/// Actions are ordered to match Finder's context menu layout.
enum FileAction: String, CaseIterable, Identifiable {
    // Open section
    case open
    case openWith
    case openInNewTab
    
    // Quick Look
    case viewLister
    
    // Edit section
    case cut
    case copy
    case paste
    case duplicate
    
    // Operations section
    case compress
    case pack
    case createLink
    case share
    
    // Navigation
    case revealInFinder
    
    // Danger zone
    case rename
    case delete
    
    // Info section
    case getInfo

    // Favorites
    case addToFavorites

    var id: String { rawValue }

    /// Human-readable title for each action.
    var title: String {
        switch self {
        case .open: return "Open"
        case .openWith: return "Open With"
        case .openInNewTab: return "Open in New Tab"
        case .viewLister: return "Quick Look"
        case .cut: return "Cut"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .duplicate: return "Duplicate"
        case .compress: return "Compress"
        case .pack: return "Pack..."
        case .createLink: return "Make Alias"
        case .share: return "Share..."
        case .revealInFinder: return "Show in Finder"
        case .rename: return "Rename..."
        case .delete: return "Move to Trash"
        case .getInfo: return "Get Info"
        case .addToFavorites: return "Add to Favorites"
        }
    }

    /// SF Symbol for each action.
    var systemImage: String {
        switch self {
        case .open: return "arrow.up.doc"
        case .openWith: return "arrow.up.right.square"
        case .openInNewTab: return "plus.square.on.square"
        case .viewLister: return "eye"
        case .cut: return "scissors"
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        case .duplicate: return "plus.square.on.square"
        case .compress: return "archivebox"
        case .pack: return "doc.zipper"
        case .createLink: return "link"
        case .share: return "square.and.arrow.up"
        case .revealInFinder: return "folder"
        case .rename: return "pencil"
        case .delete: return "trash"
        case .getInfo: return "info.circle"
        case .addToFavorites: return "star.badge.plus"
        }
    }
    
    /// Keyboard shortcut hint
    var shortcutHint: String? {
        switch self {
        case .cut: return "⌘X"
        case .copy: return "⌘C"
        case .paste: return "⌘V"
        case .openInNewTab: return "⌘T"
        case .duplicate: return "⌘D"
        case .delete: return "⌘⌫"
        case .rename: return "↵"
        case .getInfo: return "⌘I"
        case .viewLister: return "Space"
        default: return nil
        }
    }
    
    /// Whether this action requires confirmation dialog
    var requiresConfirmation: Bool {
        switch self {
        case .delete: return true
        default: return false
        }
    }
    
    /// Whether this action opens a dialog for input
    var opensDialog: Bool {
        switch self {
        case .rename, .pack, .createLink: return true
        default: return false
        }
    }
    
    /// Whether this action opens a submenu
    var hasSubmenu: Bool {
        switch self {
        case .openWith: return true
        default: return false
        }
    }
    
    /// Actions that should appear in the main context menu (Finder-style order)
    static var contextMenuActions: [FileAction] {
        [
            .open,
            .openWith,
            .openInNewTab,
            .viewLister,
            // divider
            .cut,
            .copy,
            .paste,
            .duplicate,
            // divider
            .compress,
            .share,
            // divider
            .revealInFinder,
            // divider
            .rename,
            .delete,
            // divider
            .getInfo
        ]
    }
}
