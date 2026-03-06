// ColumnLayoutModel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column identity, visibility, order and width model for FileTableView.
//              Singleton store holds layouts for both panels — loaded ONCE at startup.

import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Column Drag UTType

extension UTType {
    /// Custom UTType for column header drag-and-drop reorder
    static let mimiColumnID = UTType(exportedAs: "com.senatov.miminavigator.column-id")
}

// MARK: - Column Identity

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

    // Minimum width based on header text + icon + sort arrow + padding
    var minHeaderWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let iconWidth: CGFloat = icon != nil ? 18 : 0
        let sortArrowWidth: CGFloat = 16
        let padding: CGFloat = 20
        return ceil(textWidth + iconWidth + sortArrowWidth + padding)
    }

    // Minimum width when resizing by drag — smaller than minHeaderWidth to allow narrowing
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

// MARK: - Column Spec

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

// MARK: - Column Layout Store (Singleton)

@MainActor
@Observable
final class ColumnLayoutStore {
    static let shared = ColumnLayoutStore()
    
    private(set) var left: ColumnLayoutModel
    private(set) var right: ColumnLayoutModel
    
    private init() {
        self.left = ColumnLayoutModel(panelSide: .left)
        self.right = ColumnLayoutModel(panelSide: .right)
        log.info("[ColumnLayoutStore] initialized — layouts loaded once")
    }
    
    func layout(for side: PanelSide) -> ColumnLayoutModel {
        side == .left ? left : right
    }
}

// MARK: - Column Layout Model

@MainActor
@Observable
final class ColumnLayoutModel {
    static let defaultOrder: [ColumnID] = [
        .name, .dateModified, .size, .kind, .permissions, .owner, .childCount,
        .dateCreated, .dateLastOpened, .dateAdded, .group
    ]

    var columns: [ColumnSpec]
    
    /// Version counter for efficient change detection in NSTableView
    private(set) var layoutVersion: Int = 0

    private let storageKey: String

    init(panelSide: PanelSide) {
        self.storageKey = "ColumnLayout.\(panelSide.rawValue)"
        self.columns = Self.defaultOrder.map { ColumnSpec(id: $0) }
        load()
    }

    var visibleColumns: [ColumnSpec] {
        columns.filter { $0.isVisible }
    }

    func toggle(_ id: ColumnID) {
        guard !id.isRequired, let idx = columns.firstIndex(where: { $0.id == id }) else { return }
        columns[idx].isVisible.toggle()
        save()
    }

    func setWidth(_ width: CGFloat, for id: ColumnID) {
        if let idx = columns.firstIndex(where: { $0.id == id }) {
            columns[idx].width = max(id.minDragWidth, min(width, TableColumnDefaults.maxWidth))
            layoutVersion += 1
        }
    }

    func saveWidths() { save() }

    func canMove(_ id: ColumnID) -> Bool { id != .name }

    func moveColumn(_ sourceID: ColumnID, before targetID: ColumnID) {
        guard sourceID != .name, targetID != .name, sourceID != targetID else { return }
        guard let srcIdx = columns.firstIndex(where: { $0.id == sourceID }),
              columns.firstIndex(where: { $0.id == targetID }) != nil else { return }
        let spec = columns.remove(at: srcIdx)
        let insertIdx = columns.firstIndex(where: { $0.id == targetID }) ?? columns.endIndex
        columns.insert(spec, at: insertIdx)
        save()
    }

    func moveColumnToEnd(_ sourceID: ColumnID) {
        guard sourceID != .name, let srcIdx = columns.firstIndex(where: { $0.id == sourceID }) else { return }
        let spec = columns.remove(at: srcIdx)
        columns.append(spec)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(columns) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ColumnSpec].self, from: data) else { return }
        var merged = saved
        for col in Self.defaultOrder where !merged.contains(where: { $0.id == col }) {
            merged.append(ColumnSpec(id: col))
        }
        // Name always first and visible
        if let idx = merged.firstIndex(where: { $0.id == .name }), idx != 0 {
            let spec = merged.remove(at: idx)
            merged.insert(spec, at: 0)
        }
        merged[0].isVisible = true
        for j in merged.indices { let dw = merged[j].id.defaultWidth; if dw > 0 && (merged[j].width > dw * 2 || merged[j].width < merged[j].id.minDragWidth) { merged[j].width = dw } }
        columns = merged
    }
}
