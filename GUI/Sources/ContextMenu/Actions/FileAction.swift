//
// FileAction.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 08.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

/// Represents context actions available for a regular file.
enum FileAction: String, CaseIterable, Identifiable {
    case open
    case cut
    case copy
    case paste
    case pack
    case viewLister
    case createLink
    case delete
    case rename
    case properties

    var id: String { rawValue }

    /// Human-readable title for each action.
    var title: String {
        switch self {
        case .open: return "Open"
        case .cut: return "Cut"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .pack: return "Pack..."
        case .viewLister: return "View (Quick Look)"
        case .createLink: return "Create Link..."
        case .delete: return "Move to Trash"
        case .rename: return "Rename..."
        case .properties: return "Properties..."
        }
    }

    /// SF Symbol for each action.
    var systemImage: String {
        switch self {
        case .open: return "arrow.up.doc"
        case .cut: return "scissors"
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        case .pack: return "archivebox"
        case .viewLister: return "eye"
        case .createLink: return "link"
        case .delete: return "trash"
        case .rename: return "pencil"
        case .properties: return "info.circle"
        }
    }
    
    /// Keyboard shortcut hint
    var shortcutHint: String? {
        switch self {
        case .cut: return "⌘X"
        case .copy: return "⌘C"
        case .paste: return "⌘V"
        case .delete: return "⌘⌫"
        case .rename: return "F2"
        case .properties: return "⌘I"
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
        case .rename, .pack, .createLink, .properties: return true
        default: return false
        }
    }
}
