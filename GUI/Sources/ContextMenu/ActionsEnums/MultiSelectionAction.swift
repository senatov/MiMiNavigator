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
    case paste

    // Operations
    case compress
    case share

    // Navigation
    case revealInFinder

    // Danger zone
    case delete

    var id: String { rawValue }

    /// Human-readable title for each action
    var title: String {
        switch self {
        case .cut: return "Cut"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .compress: return "Compress"
        case .share: return "Share..."
        case .revealInFinder: return "Show in Finder"
        case .delete: return "Move to Trash"
        }
    }

    /// SF Symbol icon
    var systemImage: String {
        switch self {
        case .cut: return "scissors"
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        case .compress: return "archivebox"
        case .share: return "square.and.arrow.up"
        case .revealInFinder: return "folder"
        case .delete: return "trash"
        }
    }

    /// Keyboard shortcut hint
    var shortcutHint: String? {
        switch self {
        case .cut: return "⌘X"
        case .copy: return "⌘C"
        case .paste: return "⌘V"
        case .delete: return "⌘⌫"
        default: return nil
        }
    }
}
