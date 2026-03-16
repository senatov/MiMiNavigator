// ColumnLayoutModel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column layout model — visibility, order, width per panel.
//              Persisted in UserDefaults.
//
// Sub-components (separate files):
//   ColumnID.swift          — column identity enum
//   ColumnSpec.swift        — single column spec struct
//   ColumnLayoutStore.swift — singleton store for both panels

import FileModelKit
import SwiftUI

// MARK: - ColumnLayoutModel
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
        log.debug("[ColumnLayout] init panel=\(panelSide) defaultColumns=\(columns.count)")
        load()
        log.debug("[ColumnLayout] after load panel=\(panelSide) columns=\(columns.count)")
        for c in columns {
            log.debug("[ColumnLayout] panel=\(panelSide) id=\(c.id) width=\(c.width) visible=\(c.isVisible)")
        }
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
        MiMiDefaults.shared.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = MiMiDefaults.shared.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ColumnSpec].self, from: data) else {
            log.debug("[ColumnLayout] no saved layout for key=\(storageKey)")
            return
        }
        log.debug("[ColumnLayout] loaded saved layout key=\(storageKey) count=\(saved.count)")
        for c in saved {
            log.debug("[ColumnLayout] saved id=\(c.id) width=\(c.width) visible=\(c.isVisible)")
        }
        var merged = saved
        for col in Self.defaultOrder where !merged.contains(where: { $0.id == col }) {
            merged.append(ColumnSpec(id: col))
        }
        if let idx = merged.firstIndex(where: { $0.id == .name }), idx != 0 {
            let spec = merged.remove(at: idx)
            merged.insert(spec, at: 0)
        }
        merged[0].isVisible = true
        for j in merged.indices { let dw = merged[j].id.defaultWidth; if dw > 0 && (merged[j].width > dw * 2 || merged[j].width < merged[j].id.minDragWidth) { merged[j].width = dw } }
        columns = merged
    }
}
