// ColumnLayoutModel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column identity, visibility, order and width model for FileTableView.
//              Supports show/hide via header context menu, drag-to-reorder (future),
//              and full persistence in UserDefaults per panel side.

import FileModelKit
import SwiftUI

// MARK: - Column Identity

enum ColumnID: String, CaseIterable, Codable, Identifiable {
    case name = "name"
    case dateModified = "dateModified"
    case size = "size"
    case kind = "kind"
    case permissions = "permissions"
    case owner = "owner"
    case childCount = "childCount"
    case dateCreated = "dateCreated"
    case dateLastOpened = "dateLastOpened"
    case dateAdded = "dateAdded"
    case group = "group"

    var id: String { rawValue }

    var title: String {
        switch self {
            case .name: return "Name"
            case .dateModified: return "Date Mod."
            case .size: return "Size"
            case .kind: return "Kind"
            case .permissions: return "Permiss."
            case .owner: return "Owner"
            case .childCount: return "Count"
            case .dateCreated: return "Created"
            case .dateLastOpened: return "Last Open"
            case .dateAdded: return "Added"
            case .group: return "Group"
        }
    }

    /// SF Symbol icon for compact column headers (nil = text-only)
    var icon: String? {
        switch self {
            case .name: return nil
            case .dateModified: return nil
            case .size: return nil
            case .kind: return nil
            case .permissions: return "lock.shield"
            case .owner: return "person"
            case .childCount: return "number"
            case .dateCreated: return nil
            case .dateLastOpened: return nil
            case .dateAdded: return nil
            case .group: return "person.2"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
            case .name: return 0  // flexible — fills remaining space
            case .dateModified: return 130
            case .size: return 75
            case .kind: return 60
            case .permissions: return 80
            case .owner: return 70
            case .childCount: return 80
            case .dateCreated: return 130
            case .dateLastOpened: return 130
            case .dateAdded: return 130
            case .group: return 70
        }
    }

    /// Columns that are visible by default (extended columns off by default)
    var defaultVisible: Bool {
        switch self {
            case .dateCreated, .dateLastOpened, .dateAdded, .group: return false
            default: return true
        }
    }

    /// Columns that can never be hidden (Name is mandatory)
    var isRequired: Bool { self == .name }

    /// Alignment of the column content
    var alignment: Alignment {
        switch self {
            case .size, .childCount: return .trailing
            case .dateModified, .dateCreated, .dateLastOpened, .dateAdded: return .center
            default: return .leading
        }
    }

    /// Per-column content text color (used in file rows)
    var columnColor: Color {
        switch self {
            case .name:                          return Color(#colorLiteral(red: 0.05, green: 0.10, blue: 0.30, alpha: 1.0))  // dark navy
            case .size:                          return Color(#colorLiteral(red: 0.50, green: 0.05, blue: 0.18, alpha: 1.0))  // dark raspberry
            case .kind:                          return Color(#colorLiteral(red: 0.28, green: 0.14, blue: 0.05, alpha: 1.0))  // dark brown
            case .dateModified, .dateCreated,
                 .dateLastOpened, .dateAdded:    return Color(#colorLiteral(red: 0.05, green: 0.28, blue: 0.10, alpha: 1.0))  // dark green
            case .childCount:                    return Color(#colorLiteral(red: 0.05, green: 0.10, blue: 0.30, alpha: 1.0))  // dark navy
            default:                             return Color(#colorLiteral(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0))  // dark grey
        }
    }

    /// Sort key for this column (nil = not sortable)
    var sortKey: SortKeysEnum? {
        switch self {
            case .name: return .name
            case .dateModified: return .date
            case .size: return .size
            case .kind: return .type
            case .permissions: return .permissions
            case .owner: return .owner
            case .childCount: return .childCount
            case .dateCreated: return nil
            case .dateLastOpened: return nil
            case .dateAdded: return nil
            case .group: return nil
        }
    }
}

// MARK: - Column Spec (one entry in the ordered list)

struct ColumnSpec: Codable, Identifiable, Equatable {
    var id: ColumnID
    var width: CGFloat
    var isVisible: Bool

    init(id: ColumnID, width: CGFloat? = nil, isVisible: Bool? = nil) {
        self.id = id
        self.width = width ?? id.defaultWidth
        self.isVisible = isVisible ?? id.defaultVisible
    }
}

// MARK: - Column Layout Model

@MainActor
@Observable
final class ColumnLayoutModel {

    // MARK: - Default ordered column list (Finder-style: Name, Date, Size, Kind, Perms, Owner, ChildCount)
    static let defaultOrder: [ColumnID] = [
        .name, .dateModified, .size, .kind, .permissions, .owner, .childCount,
        .dateCreated, .dateLastOpened, .dateAdded, .group,
    ]

    // MARK: - State
    var columns: [ColumnSpec]

    // MARK: - Persistence key
    private let storageKey: String
    // Guard: UserDefaults I/O must run only once per instance lifetime.
    // PanelFileTableSection is a struct — its init() runs on every SwiftUI render pass,
    // but @State keeps the ColumnLayoutModel class alive across renders.
    private var didLoad = false

    // MARK: - Init
    init(panelSide: PanelSide) {
        self.storageKey = "ColumnLayout.\(panelSide.rawValue)"
        self.columns = Self.defaultOrder.map { ColumnSpec(id: $0) }
        loadOnce()
    }

    // MARK: - One-shot load guard
    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        load()
    }

    // MARK: - Visible columns in order
    var visibleColumns: [ColumnSpec] {
        columns.filter { $0.isVisible }
    }

    // MARK: - Toggle visibility
    func toggle(_ id: ColumnID) {
        guard !id.isRequired else { return }
        if let idx = columns.firstIndex(where: { $0.id == id }) {
            columns[idx].isVisible.toggle()
            save()
        }
    }

    // MARK: - Update width
    func setWidth(_ width: CGFloat, for id: ColumnID) {
        if let idx = columns.firstIndex(where: { $0.id == id }) {
            columns[idx].width = max(TableColumnDefaults.minWidth, min(width, TableColumnDefaults.maxWidth))
        }
    }

    func saveWidths() { save() }

    // MARK: - Persistence
    private func save() {
        if let data = try? JSONEncoder().encode(columns) {
            UserDefaults.standard.set(data, forKey: storageKey)
            log.debug("[ColumnLayout] saved \(storageKey)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([ColumnSpec].self, from: data)
        else { return }

        // Merge saved with defaults: add new columns, keep saved order and widths
        var merged: [ColumnSpec] = saved
        for defaultCol in Self.defaultOrder {
            if !merged.contains(where: { $0.id == defaultCol }) {
                merged.append(ColumnSpec(id: defaultCol))
            }
        }
        // Ensure Name is always visible and first
        if let nameIdx = merged.firstIndex(where: { $0.id == .name }), nameIdx != 0 {
            let nameSpec = merged.remove(at: nameIdx)
            merged.insert(nameSpec, at: 0)
        }
        if let nameIdx = merged.firstIndex(where: { $0.id == .name }) {
            merged[nameIdx].isVisible = true
        }
        columns = merged
        log.debug("[ColumnLayout] loaded \(storageKey): \(columns.map { "\($0.id.rawValue):\($0.isVisible)" })")
    }
}
