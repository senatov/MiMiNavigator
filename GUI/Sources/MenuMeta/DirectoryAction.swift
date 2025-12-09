//
// DirAction.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 08.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

// / Represents all possible context actions available for a dir.
enum DirectoryAction: String, CaseIterable, Identifiable {
    case open
    case openInNewTab
    case viewLister
    case cut
    case copy
    case pack
    case createLink
    case delete
    case rename
    case properties

    var id: String { rawValue }

    // / Human-readable title for each action.
    var title: String {
        switch self {
            case .open: return "Open"
            case .openInNewTab: return "Open in New Tab"
            case .viewLister: return "View Lister"
            case .cut: return "Cut"
            case .copy: return "Copy"
            case .pack: return "Pack"
            case .createLink: return "Create Link"
            case .delete: return "Delete"
            case .rename: return "Rename"
            case .properties: return "Properties"
        }
    }

    // / System image name for SF Symbol icon.
    var systemImage: String {
        switch self {
            case .open: return "folder.fill"
            case .openInNewTab: return "plus.square.on.square"
            case .viewLister: return "list.bullet.rectangle"
            case .cut: return "scissors"
            case .copy: return "doc.on.doc"
            case .pack: return "archivebox"
            case .createLink: return "link"
            case .delete: return "trash"
            case .rename: return "pencil"
            case .properties: return "info.circle"
        }
    }
}
