// ToolbarStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: @Observable store for toolbar button order and visibility.
//   Persists to UserDefaults as JSON. Mirrors pattern of HotKeyStore.

import Foundation

// MARK: - Toolbar Store
/// Holds the ordered list of all toolbar items and which are visible.
/// Observable — SwiftUI toolbar re-renders automatically on any change.
@MainActor
@Observable
final class ToolbarStore {

    static let shared = ToolbarStore()

    // MARK: - State
    /// Full ordered list of item IDs (visible + hidden).
    /// Position in array = position in toolbar (for visible items).
    private(set) var orderedIDs: [ToolbarItemID]

    /// Set of currently visible item IDs.
    private(set) var visibleIDs: Set<ToolbarItemID>

    /// Whether the top menu bar (Files, Mark, Commands…) is visible.
    /// Default: true. Persisted in UserDefaults.
    var menuBarVisible: Bool = true {  // observed by @Observable automatically
        didSet { saveMenuBarVisible() }
    }

    // MARK: - Persistence key
    private let orderKey      = "com.senatov.MiMiNavigator.toolbar.order"
    private let visibilityKey  = "com.senatov.MiMiNavigator.toolbar.visible"
    private let menuBarKey     = "com.senatov.MiMiNavigator.toolbar.menuBarVisible"

    // MARK: - Init
    private init() {
        // Temporary values before load
        orderedIDs = ToolbarItemID.defaultOrder
        visibleIDs = Set(ToolbarItemID.defaultOrder)
        load()
    }

    // MARK: - Public API

    /// Ordered items that are currently visible in the toolbar.
    var visibleItems: [ToolbarItemID] {
        orderedIDs.filter { visibleIDs.contains($0) }
    }

    /// Ordered items that can be customized in the dialog.
    var customizableItems: [ToolbarItemID] {
        orderedIDs.filter { !$0.isFixed }
    }

    /// Visible customizable items shown in the current toolbar strip.
    var customizableVisibleItems: [ToolbarItemID] {
        customizableItems.filter { visibleIDs.contains($0) }
    }

    /// Ordered items that are currently hidden (shown as disabled in palette).
    var hiddenItems: [ToolbarItemID] {
        orderedIDs.filter { !visibleIDs.contains($0) }
    }

    /// Minimum number of buttons that must remain visible at all times.
    static let minVisibleCount = 1

    /// Toggle visibility of a single item.
    /// Refuses to hide fixed items or if this is the last visible button.
    func toggleVisibility(_ id: ToolbarItemID) {
        guard !id.isFixed else { return }  // fixed items are always visible
        if visibleIDs.contains(id) {
            guard customizableVisibleItems.count > ToolbarStore.minVisibleCount else {
                log.warning("[Toolbar] cannot hide \(id.rawValue) — minimum 1 visible")
                return
            }
            visibleIDs.remove(id)
        } else {
            visibleIDs.insert(id)
        }
        save()
        log.debug("[Toolbar] toggled \(id.rawValue) → visible=\(visibleIDs.contains(id))")
    }

    /// Hides a visible customizable item without using toggle semantics.
    func hideItem(_ id: ToolbarItemID) {
        guard !id.isFixed, visibleIDs.contains(id) else { return }
        guard customizableVisibleItems.count > ToolbarStore.minVisibleCount else {
            log.warning("[Toolbar] cannot hide \(id.rawValue) — minimum 1 visible")
            return
        }
        visibleIDs.remove(id)
        save()
        log.debug("[Toolbar] hid \(id.rawValue)")
    }

    /// Move item at source index to destination index (drag reorder within palette).
    func move(fromOffsets: IndexSet, toOffset: Int) {
        orderedIDs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        save()
        log.debug("[Toolbar] reordered — new order: \(orderedIDs.map(\.rawValue))")
    }

    /// Reposition a visible item inside the current toolbar strip.
    func moveVisibleItem(_ id: ToolbarItemID, toVisibleIndex targetVisibleIndex: Int) {
        guard visibleIDs.contains(id), let fromOrderedIndex = orderedIDs.firstIndex(of: id) else { return }

        let remainingVisibleItems = visibleItems.filter { $0 != id }
        let insertionIndex = max(0, min(targetVisibleIndex, remainingVisibleItems.count))
        let destination = orderedDestination(for: insertionIndex, visibleSequence: remainingVisibleItems, moving: id)
        orderedIDs.move(fromOffsets: IndexSet(integer: fromOrderedIndex), toOffset: destination)
        save()
        log.debug("[Toolbar] moved visible item \(id.rawValue) to visibleIndex=\(insertionIndex)")
    }

    /// Makes a hidden item visible and inserts it at the requested toolbar position.
    func showItem(_ id: ToolbarItemID, atVisibleIndex targetVisibleIndex: Int) {
        guard !id.isFixed else { return }
        guard !visibleIDs.contains(id) else {
            moveVisibleItem(id, toVisibleIndex: targetVisibleIndex)
            return
        }
        visibleIDs.insert(id)
        guard let fromOrderedIndex = orderedIDs.firstIndex(of: id) else {
            save()
            return
        }
        let currentVisibleItems = visibleItems.filter { $0 != id }
        let insertionIndex = max(0, min(targetVisibleIndex, currentVisibleItems.count))
        let destination = orderedDestination(for: insertionIndex, visibleSequence: currentVisibleItems, moving: id)
        orderedIDs.move(fromOffsets: IndexSet(integer: fromOrderedIndex), toOffset: destination)
        save()
        log.debug("[Toolbar] showed item \(id.rawValue) at visibleIndex=\(insertionIndex)")
    }

    /// Reset order and visibility to factory defaults.
    func resetToDefaults() {
        orderedIDs = ToolbarItemID.defaultOrder
        visibleIDs = Set(ToolbarItemID.defaultOrder)
        menuBarVisible = true
        save()
        log.info("[Toolbar] reset to defaults")
    }

    // MARK: - Persistence

    private func load() {
        let ud = MiMiDefaults.shared
        // Load order
        if let rawOrder = ud.array(forKey: orderKey) as? [String] {
            let decoded = rawOrder.compactMap { ToolbarItemID(rawValue: $0) }
                .filter { !$0.isFixed }
            let knownSaved = Set(decoded)
            let newIDs = ToolbarItemID.allCases.filter { !$0.isFixed && !knownSaved.contains($0) }
            orderedIDs = decoded + newIDs
        }

        // Load visibility — new IDs not in saved set are added as visible by default
        if let rawVisible = ud.array(forKey: visibilityKey) as? [String] {
            let saved = Set(rawVisible.compactMap { ToolbarItemID(rawValue: $0) }.filter { !$0.isFixed })
            let knownSaved = Set(rawVisible)  // raw strings that were in MiMiDefaults
            let brandNew = ToolbarItemID.allCases.filter {
                !$0.isFixed && !knownSaved.contains($0.rawValue)
            }
            visibleIDs = saved.union(Set(brandNew))
        } else {
            visibleIDs = Set(ToolbarItemID.defaultOrder)
        }

        // Load menu bar visibility (default = true)
        if ud.object(forKey: menuBarKey) != nil {
            menuBarVisible = ud.bool(forKey: menuBarKey)
        }
        log.info("[Toolbar] loaded — order: \(orderedIDs.map(\.rawValue)), visible: \(visibleIDs.map(\.rawValue).sorted()), menuBar=\(menuBarVisible)")
    }

    private func save() {
        MiMiDefaults.shared.set(orderedIDs.map(\.rawValue), forKey: orderKey)
        MiMiDefaults.shared.set(visibleIDs.map(\.rawValue), forKey: visibilityKey)
    }

    private func saveMenuBarVisible() {
        MiMiDefaults.shared.set(menuBarVisible, forKey: menuBarKey)
        log.debug("[Toolbar] menuBarVisible=\(menuBarVisible) saved")
    }

    private func orderedDestination(
        for targetVisibleIndex: Int,
        visibleSequence: [ToolbarItemID],
        moving id: ToolbarItemID
    ) -> Int {
        guard targetVisibleIndex < visibleSequence.count else { return orderedIDs.count }
        let anchor = visibleSequence[targetVisibleIndex]
        guard
            let anchorIndex = orderedIDs.firstIndex(of: anchor),
            let currentIndex = orderedIDs.firstIndex(of: id)
        else {
            return orderedIDs.count
        }
        return anchorIndex < currentIndex ? anchorIndex : anchorIndex + 1
    }
}
