// ColumnLayoutModel.swift
// MiMiNavigator — Column layout model: visibility, order, width per panel.
// Persisted via ColumnLayoutStore.

import FileModelKit
import SwiftUI

@Observable
final class ColumnLayoutModel: Codable {

    // MARK: - Constants

    static let defaultOrder: [ColumnID] = [
        .name, .dateModified, .size, .kind, .permissions, .owner, .childCount,
        .dateCreated, .dateLastOpened, .dateAdded, .group,
    ]

    private static let dividerWidth: CGFloat = 14
    private static let minNameWidth: CGFloat = 60
    private static let edgeMargin: CGFloat = 5

    // MARK: - Stored Properties

    var columns: [ColumnSpec]
    private(set) var layoutVersion: Int = 0
    var containerWidth: CGFloat = 0
    private(set) var storedNameWidth: CGFloat = 200
    private let storageKey: String

    // MARK: - Computed Properties

    var visibleColumns: [ColumnSpec] { columns.filter { $0.isVisible } }
    var fixedColumns: [ColumnSpec] { visibleColumns.filter { $0.id != .name } }

    var nameWidth: CGFloat {
        get { storedNameWidth }
        set { setNameWidth(newValue) }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case columns, storedNameWidth }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.columns = try c.decode([ColumnSpec].self, forKey: .columns)
        self.storedNameWidth = try c.decodeIfPresent(CGFloat.self, forKey: .storedNameWidth) ?? 200
        self.storageKey = ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(columns, forKey: .columns)
        try c.encode(storedNameWidth, forKey: .storedNameWidth)
    }

    // MARK: - Init

    init(panelSide: FavPanelSide) {
        self.storageKey = "ColumnLayout.\(panelSide.rawValue)"
        self.columns = Self.defaultOrder.map { ColumnSpec(id: $0) }
        load()
    }

    // MARK: - Name Width

    private func setNameWidth(_ value: CGFloat) {
        let maxNameW = calculateMaxNameWidth()
        let clamped = value.clamped(to: Self.minNameWidth...maxNameW)
        guard abs(storedNameWidth - clamped) > 0.5 else { return }
        storedNameWidth = clamped
        layoutVersion += 1
    }

    func updateNameWidthForContainer() {
        let maxNameW = calculateMaxNameWidth()
        if storedNameWidth > maxNameW {
            storedNameWidth = Swift.max(Self.minNameWidth, maxNameW)
        }
    }

    private func calculateMaxNameWidth() -> CGFloat {
        guard containerWidth > 0 else { return 9999 }
        // dividers: N total (1 nameDivider + N-1 between fixed cols = N)
        let divTotal = CGFloat(fixedColumns.count) * Self.dividerWidth
        let minFixedTotal = fixedColumns.reduce(0) { $0 + $1.id.minDragWidth }
        return containerWidth - minFixedTotal - divTotal - Self.edgeMargin
    }

    // MARK: - Column Width

    func setWidth(_ width: CGFloat, for id: ColumnID) {
        guard let idx = columns.firstIndex(where: { $0.id == id }) else { return }
        let clamped = width.clamped(to: id.minDragWidth...id.maxWidth)
        columns[idx].width = clamped
        layoutVersion += 1
    }

    // MARK: - Visibility

    @MainActor
    func toggle(_ id: ColumnID) {
        guard !id.isRequired, let idx = columns.firstIndex(where: { $0.id == id }) else { return }
        columns[idx].isVisible.toggle()
        save()
    }

    // MARK: - Reordering

    func canMove(_ id: ColumnID) -> Bool { id != .name }

    @MainActor
    func moveColumn(_ sourceID: ColumnID, before targetID: ColumnID) {
        guard sourceID != .name, targetID != .name, sourceID != targetID,
            let srcIdx = columns.firstIndex(where: { $0.id == sourceID }),
            columns.firstIndex(where: { $0.id == targetID }) != nil
        else { return }

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

    // MARK: - Persistence

    @MainActor func saveWidths() { save() }
    @MainActor private func save() { ColumnLayoutStore.shared.saveToDisk() }
    private func load() { /* handled by ColumnLayoutStore */  }
}

// MARK: - CGFloat Extension

extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
