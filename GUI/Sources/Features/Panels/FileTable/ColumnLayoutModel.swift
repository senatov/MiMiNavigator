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
    @Observable
    final class ColumnLayoutModel: Codable {
        static let defaultOrder: [ColumnID] = [
            .name, .dateModified, .size, .kind, .permissions, .owner, .childCount,
            .dateCreated, .dateLastOpened, .dateAdded, .group
        ]

        var columns: [ColumnSpec]

        /// Version counter for efficient change detection in NSTableView
        private(set) var layoutVersion: Int = 0

        private let storageKey: String

        private enum CodingKeys: String, CodingKey {
            case columns
        }

        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.columns = try container.decode([ColumnSpec].self, forKey: .columns)
            self.storageKey = ""
            self.layoutVersion = 0
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(columns, forKey: .columns)
        }

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

        @MainActor
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

        @MainActor
        func saveWidths() { save() }

        func canMove(_ id: ColumnID) -> Bool { id != .name }

        @MainActor
        func moveColumn(_ sourceID: ColumnID, before targetID: ColumnID) {
            guard sourceID != .name, targetID != .name, sourceID != targetID else { return }
            guard let srcIdx = columns.firstIndex(where: { $0.id == sourceID }),
                  columns.firstIndex(where: { $0.id == targetID }) != nil else { return }
            let spec = columns.remove(at: srcIdx)
            let insertIdx = columns.firstIndex(where: { $0.id == targetID }) ?? columns.endIndex
            columns.insert(spec, at: insertIdx)
            save()
        }

        @MainActor
        func moveColumnToEnd(_ sourceID: ColumnID) {
            guard sourceID != .name, let srcIdx = columns.firstIndex(where: { $0.id == sourceID }) else { return }
            let spec = columns.remove(at: srcIdx)
            columns.append(spec)
            save()
        }

        @MainActor
        private func save() {
            ColumnLayoutStore.shared.saveToDisk()
        }

        private func load() {
            // Loading handled by ColumnLayoutStore
        }
    }
