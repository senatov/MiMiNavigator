// ColumnLayoutModel.swift
// MiMiNavigator — Column layout model: visibility, order, width per panel.
// Persisted via ColumnLayoutStore.

import FileModelKit
import SwiftUI

@Observable
final class ColumnLayoutModel: Codable {

    static let defaultOrder: [ColumnID] = [
        .name, .dateModified, .size, .kind, .permissions, .owner, .childCount,
        .dateCreated, .dateLastOpened, .dateAdded, .group,
    ]

    private enum LayoutMetrics {
        static let dividerWidth: CGFloat = 14
        static let minNameWidth: CGFloat = 60
        static let trailingContentInset: CGFloat = 17
        static let widthChangeEpsilon: CGFloat = 0.5
        static let unconstrainedWidthFallback: CGFloat = 9_999
    }

    var columns: [ColumnSpec]
    private(set) var layoutVersion: Int = 0
    var containerWidth: CGFloat = 0
    private(set) var storedNameWidth: CGFloat = 200
    private let storageKey: String

    var visibleColumns: [ColumnSpec] { columns.filter { $0.isVisible } }
    var fixedColumns: [ColumnSpec] { visibleColumns.filter { $0.id != .name } }

    var nameWidth: CGFloat {
        get { storedNameWidth }
        set { applyNameWidth(newValue) }
    }

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

    init(panelSide: FavPanelSide) {
        self.storageKey = "ColumnLayout.\(panelSide.rawValue)"
        self.columns = Self.defaultOrder.map { ColumnSpec(id: $0) }
        load()
    }

    private func applyNameWidth(_ value: CGFloat) {
        let clampedWidth = clampNameWidth(value)
        applyStoredNameWidthIfNeeded(clampedWidth)
    }

    func updateNameWidthForContainer() {
        let clampedWidth = clampNameWidth(storedNameWidth)
        applyStoredNameWidthIfNeeded(clampedWidth)
    }

    /// Max Name width accounting for all visible fixed columns. Used by divider drag constraint.
    var effectiveMaxNameWidth: CGFloat { maximumNameWidth }
    private var maximumNameWidth: CGFloat {
        guard containerWidth > 0 else { return LayoutMetrics.unconstrainedWidthFallback }

        let dividerTotal = totalDividerWidth(for: fixedColumns.count)
        let currentFixedWidth = totalFixedWidth(for: fixedColumns)
        let availableWidth = containerWidth - currentFixedWidth - dividerTotal - LayoutMetrics.trailingContentInset

        return max(LayoutMetrics.minNameWidth, availableWidth)
    }

    private func totalFixedWidth(for columns: [ColumnSpec]) -> CGFloat {
        columns.reduce(CGFloat.zero) { partial, spec in
            partial + spec.width
        }
    }

    func setWidth(_ width: CGFloat, for id: ColumnID) {
        guard let index = indexOfColumn(with: id) else { return }

        if id == .name {
            applyNameWidth(width)
            return
        }

        let clampedWidth = clampWidth(width, for: id)
        guard shouldApplyWidthChange(current: columns[index].width, new: clampedWidth) else { return }

        columns[index].width = clampedWidth
        updateNameWidthForContainer()
        incrementLayoutVersion()
    }

    private func calculateMaxWidth(for id: ColumnID) -> CGFloat {
        guard containerWidth > 0 else { return max(id.maxWidth, LayoutMetrics.unconstrainedWidthFallback) }

        let remainingFixedColumns = fixedColumns.filter { $0.id != id }
        let dividerTotal = totalDividerWidth(for: fixedColumns.count)
        let remainingFixedWidth = totalFixedWidth(for: remainingFixedColumns)

        let maximumWidth = containerWidth
            - storedNameWidth
            - remainingFixedWidth
            - dividerTotal
            - LayoutMetrics.trailingContentInset

        return max(id.minDragWidth, maximumWidth)
    }

    private func totalDividerWidth(for fixedColumnCount: Int) -> CGFloat {
        CGFloat(fixedColumnCount) * LayoutMetrics.dividerWidth
    }

    private func clampNameWidth(_ value: CGFloat) -> CGFloat {
        value.clamped(to: LayoutMetrics.minNameWidth...maximumNameWidth)
    }

    private func clampWidth(_ width: CGFloat, for id: ColumnID) -> CGFloat {
        width.clamped(to: id.minDragWidth...calculateMaxWidth(for: id))
    }

    private func applyStoredNameWidthIfNeeded(_ width: CGFloat) {
        guard shouldApplyWidthChange(current: storedNameWidth, new: width) else { return }
        storedNameWidth = width
        incrementLayoutVersion()
    }

    private func shouldApplyWidthChange(current: CGFloat, new: CGFloat) -> Bool {
        abs(current - new) > LayoutMetrics.widthChangeEpsilon
    }

    private func incrementLayoutVersion() {
        layoutVersion += 1
    }

    private func indexOfColumn(with id: ColumnID) -> Int? {
        columns.firstIndex(where: { $0.id == id })
    }

    @MainActor
    func toggle(_ id: ColumnID) {
        guard !id.isRequired, let idx = columns.firstIndex(where: { $0.id == id }) else { return }
        columns[idx].isVisible.toggle()
        save()
    }

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

    @MainActor
    func saveWidths() { save() }
    @MainActor private func save() { ColumnLayoutStore.shared.saveToDisk() }
    private func load() {}
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
