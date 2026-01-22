//
// DirectoryAction.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 08.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

/// Represents all possible context actions available for a directory.
enum DirectoryAction: String, CaseIterable, Identifiable {
    case open
    case openInNewTab
    case openInFinder
    case openInTerminal
    case viewLister
    case cut
    case copy
    case paste
    case pack
    case createLink
    case delete
    case rename
    case properties

    var id: String { rawValue }

    /// Human-readable title for each action.
    var title: String {
        switch self {
        case .open: return "Open"
        case .openInNewTab: return "Open in New Tab"
        case .openInFinder: return "Show in Finder"
        case .openInTerminal: return "Open in Terminal"
        case .viewLister: return "View Contents"
        case .cut: return "Cut"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .pack: return "Pack..."
        case .createLink: return "Create Link..."
        case .delete: return "Move to Trash"
        case .rename: return "Rename..."
        case .properties: return "Properties..."
        }
    }

    /// System image name for SF Symbol icon.
    var systemImage: String {
        switch self {
        case .open: return "folder.fill"
        case .openInNewTab: return "plus.square.on.square"
        case .openInFinder: return "folder.badge.gearshape"
        case .openInTerminal: return "terminal"
        case .viewLister: return "list.bullet.rectangle"
        case .cut: return "scissors"
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        case .pack: return "archivebox"
        case .createLink: return "link"
        case .delete: return "trash"
        case .rename: return "pencil"
        case .properties: return "info.circle"
        }
    }
    
    /// Keyboard shortcut hint
    var shortcutHint: String? {
        switch self {
        case .open: return "↵"
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
