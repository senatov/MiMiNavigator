//
// FileAction.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 08.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

// / Represents context actions available for a regular file.
enum FileAction: String, CaseIterable, Identifiable {
    case cut
    case copy
    case pack
    case viewLister
    case createLink
    case delete
    case rename
    case properties

    var id: String { rawValue }

    // / Human-readable title for each action.
    var title: String {
        switch self {
            case .cut: return "Cut"
            case .copy: return "Copy"
            case .pack: return "Pack files"
            case .viewLister: return "View (Lister)"
            case .createLink: return "Create Link"
            case .delete: return "Delete"
            case .rename: return "Rename"
            case .properties: return "Properties"
        }
    }

    // / SF Symbol for each action.
    var systemImage: String {
        switch self {
            case .cut: return "scissors"
            case .copy: return "doc.on.doc"
            case .pack: return "archivebox"
            case .viewLister: return "list.bullet.rectangle"
            case .createLink: return "link"
            case .delete: return "trash"
            case .rename: return "pencil"
            case .properties: return "info.circle"
        }
    }
}
