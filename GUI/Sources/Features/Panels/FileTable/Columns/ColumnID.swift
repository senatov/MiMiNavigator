// ColumnID.swift
// MiMiNavigator
// Created by Iakov Senatov on 20.02.2026.
// Description: Column identity — titles, icons, widths, alignment, sort keys.
//
// Width policy — char count × glyph "0" width at column font + 5pt margin:

//   minDragWidth : 4pt hard floor for all columns

import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Column Drag UTType

extension UTType {
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

    // MARK: - Display

    var title: String {
        switch self {
        case .name:           "Name"
        case .dateModified:   "Date Mod."
        case .size:           "Size"
        case .kind:           "Kind"
        case .permissions:    "Permiss."
        case .owner:          "Owner"
        case .childCount:     "Count"
        case .dateCreated:    "Created"
        case .dateLastOpened: "Last Open"
        case .dateAdded:      "Added"
        case .group:          "Group"
        }
    }

    var icon: String? {
        switch self {
        case .permissions: "lock.shield"
        case .owner:       "person"
        case .childCount:  "number"
        case .group:       "person.2"
        default:           nil
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .name:                                                    0   // flexible
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: 130
        case .size:          75
        case .kind:          64
        case .permissions:   82
        case .childCount:    40
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

    // MARK: - Width limits
    // Computed once per call — NSFont alloc is cheap, cached by system.
    // "0" gives consistent digit-width reference across SF Pro variants.

    var minWidth: CGFloat {
        switch self {
        case .name:
            cw(16, .systemFont(ofSize: 12))
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded:
            cw(6,  .systemFont(ofSize: 8))
        case .size:
            cw(6,  .systemFont(ofSize: 8))
        case .kind:
            cw(6,  .systemFont(ofSize: 8))
        case .permissions:
            cw(6,  .monospacedSystemFont(ofSize: 11, weight: .regular))
        case .owner, .group:
            cw(5,  .systemFont(ofSize: 8))
        case .childCount:
            cw(2,  .systemFont(ofSize: 8))
        }
    }

    var maxWidth: CGFloat {
        switch self {
        case .name:
            cw(512, .systemFont(ofSize: 12))   // effectively unlimited
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded:
            cw(50,  .systemFont(ofSize: 12))
        case .size:
            cw(50,  .systemFont(ofSize: 12))
        case .kind:
            cw(40,  .systemFont(ofSize: 12))
        case .permissions:
            cw(20,  .monospacedSystemFont(ofSize: 11, weight: .regular))
        case .owner, .group:
            cw(40,  .systemFont(ofSize: 12))
        case .childCount:
            cw(50,  .systemFont(ofSize: 12))
        }
    }

    /// Hard drag minimum — 4pt for all columns regardless of content.
    var minDragWidth: CGFloat { 4 }

    /// Header label minimum (informational only — not used as drag floor).
    var minHeaderWidth: CGFloat {
        let f = NSFont.systemFont(ofSize: 12, weight: .medium)
        let textW = (title as NSString).size(withAttributes: [.font: f]).width
        let iconW: CGFloat = icon != nil ? 18 : 0
        return ceil(textW + iconW + 36)   // +16 sort arrow +20 padding
    }

    // MARK: - Alignment

    var alignment: Alignment {
        switch self {
        case .size, .childCount: .trailing
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: .center
        default: .leading
        }
    }

    /// per-column cell content padding (leading, trailing)
    var contentPadding: (leading: CGFloat, trailing: CGFloat) {
        switch self {
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded:
            return (3, 3)
        case .size:
            return (3, 6)
        default:
            return (TableColumnDefaults.cellPadding, TableColumnDefaults.cellPadding)
        }
    }

    /// true for all date-type columns
    var isDateColumn: Bool {
        switch self {
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: true
        default: false
        }
    }

    /// per-column header padding (leading, trailing)
    var headerPadding: (leading: CGFloat, trailing: CGFloat) {
        switch self {
        case .childCount:
            return (10, 2)
        default:
            return (TableColumnDefaults.cellPadding, TableColumnDefaults.cellPadding)
        }
    }

    // MARK: - Theming

    func columnColor(from theme: ColorTheme) -> Color {
        switch self {
        case .name:           theme.columnNameColor
        case .size:           theme.columnSizeColor
        case .kind:           theme.columnKindColor
        case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: theme.columnDateColor
        case .permissions:    theme.columnPermissionsColor
        case .owner:          theme.columnOwnerColor
        case .group:          theme.columnGroupColor
        case .childCount:     theme.columnChildCountColor
        }
    }

    // MARK: - Sort key

    var sortKey: SortKeysEnum? {
        switch self {
        case .name:          .name
        case .dateModified:  .date
        case .size:          .size
        case .kind:          .type
        case .permissions:   .permissions
        case .owner:         .owner
        case .childCount:    .childCount
        default:             nil
        }
    }

    // MARK: - Private

    /// Width of n × "0" glyphs at given font + 5pt margin.
    private func cw(_ n: Int, _ font: NSFont) -> CGFloat {
        let w = (String(repeating: "0", count: n) as NSString)
            .size(withAttributes: [.font: font]).width
        return ceil(w) + 5
    }
}
