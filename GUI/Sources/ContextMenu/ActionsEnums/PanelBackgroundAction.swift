// PanelBackgroundAction.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Context actions for empty panel area (right-click on background)

import Foundation

/// Represents context actions available when clicking on empty panel area
enum PanelBackgroundAction: String, CaseIterable, Identifiable {
    // Navigation
    case goUp
    case goBack
    case goForward
    case refresh
    
    // Create
    case newFolder
    case newFile
    
    // Clipboard
    case paste
    
    // View options
    case sortByName
    case sortByDate
    case sortBySize
    case sortByType
    
    // Navigation helpers
    case openInFinder
    case openInTerminal
    
    // Info
    case getInfo
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .goUp: return "Go Up"
        case .goBack: return "Back"
        case .goForward: return "Forward"
        case .refresh: return "Refresh"
        case .newFolder: return "New Folder"
        case .newFile: return "New File"
        case .paste: return "Paste"
        case .sortByName: return "Sort by Name"
        case .sortByDate: return "Sort by Date"
        case .sortBySize: return "Sort by Size"
        case .sortByType: return "Sort by Type"
        case .openInFinder: return "Open in Finder"
        case .openInTerminal: return "Open in Terminal"
        case .getInfo: return "Get Info"
        }
    }
    
    var systemImage: String {
        switch self {
        case .goUp: return "arrow.up"
        case .goBack: return "arrow.left"
        case .goForward: return "arrow.right"
        case .refresh: return "arrow.clockwise"
        case .newFolder: return "folder.badge.plus"
        case .newFile: return "doc.badge.plus"
        case .paste: return "doc.on.clipboard"
        case .sortByName: return "textformat.abc"
        case .sortByDate: return "calendar"
        case .sortBySize: return "internaldrive"
        case .sortByType: return "doc"
        case .openInFinder: return "folder"
        case .openInTerminal: return "terminal"
        case .getInfo: return "info.circle"
        }
    }
    
    var shortcutHint: String? {
        switch self {
        case .goUp: return "⌘↑"
        case .goBack: return "⌘["
        case .goForward: return "⌘]"
        case .refresh: return "⌘R"
        case .newFolder: return "⇧⌘N"
        case .paste: return "⌘V"
        case .getInfo: return "⌘I"
        default: return nil
        }
    }
}
