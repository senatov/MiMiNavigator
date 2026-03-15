// ColumnID.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column identity enum — defines all available table columns
//              with their titles, icons, widths, alignment, sort keys.

import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Column Drag UTType
extension UTType {
    /// Custom UTType for column header drag-and-drop reorder
    static let mimiColumnID = UTType(exportedAs: "com.senatov.miminavigator.column-id")
}

// MARK: - ColumnID
enum ColumnID: String, CaseIterable, Codable, Identifiable, Transferable {
    case name, dateModified, size, kind, permissions, owner, childCount
    case dateCreated, dateLastOpened, dateAdded, group

    var id: String { rawValue }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .mimiColumnID)
    }

    var title: String {
        switch self {
        case .name: "Name"
        case .dateModified: "Date Mod."
        case .size: "Size"
        case .kind: "Kind"
        case .permissions: "Permiss."
        case .owner: "Owner"
        case .childCount: "Count"
        case .dateCreated: "Created"
        case .dateLastOpened: "Last Open"
        case .dateAdded: "Added"
        case .group: "Group"
        }
    }

    var icon: String? {
        switch self {
        case .permissions: "lock.shield"
        case .owner: "person"
        case .childCount: "number"
        case .group: "person.2"
        default: nil
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .name: 0  // flexible
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: 130
        case .size: 75
        case .kind: 60
        case .permissions: 64
        case .childCount: 36
        case .owner, .group: 70
        }
    }

    var defaultVisible: Bool {
        switch self {
        case .dateCreated, .dateLastOpened, .dateAdded, .group: false
        default: true
        }
    }

    var isRequired: Bool { self == .name }

    var minHeaderWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let iconWidth: CGFloat = icon != nil ? 18 : 0
        let sortArrowWidth: CGFloat = 16
        let padding: CGFloat = 20
        return ceil(textWidth + iconWidth + sortArrowWidth + padding)
    }

    var minDragWidth: CGFloat {
        switch self {
        case .childCount: return 28
        case .permissions: return 40
        case .size: return 30
        case .kind: return 36
        case .owner, .group: return 36
        default: return minHeaderWidth
        }
    }

    var alignment: Alignment {
        switch self {
        case .size, .childCount: .trailing
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: .center
        default: .leading
        }
    }

    func columnColor(from theme: ColorTheme) -> Color {
        switch self {
        case .name:          theme.columnNameColor
        case .size:          theme.columnSizeColor
        case .kind:          theme.columnKindColor
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: theme.columnDateColor
        case .permissions:   theme.columnPermissionsColor
        case .owner:         theme.columnOwnerColor
        case .group:         theme.columnGroupColor
        case .childCount:    theme.columnChildCountColor
        }
    }

    var sortKey: SortKeysEnum? {
        switch self {
        case .name: .name
        case .dateModified: .date
        case .size: .size
        case .kind: .type
        case .permissions: .permissions
        case .owner: .owner
        case .childCount: .childCount
        default: nil
        }
    }
}
