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

    /// Ordered items that are currently hidden (shown as disabled in palette).
    var hiddenItems: [ToolbarItemID] {
        orderedIDs.filter { !visibleIDs.contains($0) }
    }

    /// Minimum number of buttons that must remain visible at all times.
    static let minVisibleCount = 1

    /// Toggle visibility of a single item.
    /// Refuses to hide if this is the last visible button.
    func toggleVisibility(_ id: ToolbarItemID) {
        if visibleIDs.contains(id) {
            guard visibleIDs.count > ToolbarStore.minVisibleCount else {
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

    /// Move item at source index to destination index (drag reorder within palette).
    func move(fromOffsets: IndexSet, toOffset: Int) {
        orderedIDs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        save()
        log.debug("[Toolbar] reordered — new order: \(orderedIDs.map(\.rawValue))")
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
        // Load order
        if let rawOrder = UserDefaults.standard.array(forKey: orderKey) as? [String] {
            let decoded = rawOrder.compactMap { ToolbarItemID(rawValue: $0) }
            let knownSaved = Set(decoded)
            let newIDs = ToolbarItemID.allCases.filter { !knownSaved.contains($0) }
            orderedIDs = decoded + newIDs
        }

        // Load visibility
        if let rawVisible = UserDefaults.standard.array(forKey: visibilityKey) as? [String] {
            visibleIDs = Set(rawVisible.compactMap { ToolbarItemID(rawValue: $0) })
        } else {
            visibleIDs = Set(ToolbarItemID.allCases)
        }

        // Load menu bar visibility (default = true)
        if UserDefaults.standard.object(forKey: menuBarKey) != nil {
            menuBarVisible = UserDefaults.standard.bool(forKey: menuBarKey)
        }

        log.info("[Toolbar] loaded — order: \(orderedIDs.map(\.rawValue)), visible: \(visibleIDs.map(\.rawValue).sorted()), menuBar=\(menuBarVisible)")
    }

    private func save() {
        UserDefaults.standard.set(orderedIDs.map(\.rawValue), forKey: orderKey)
        UserDefaults.standard.set(visibleIDs.map(\.rawValue), forKey: visibilityKey)
    }

    private func saveMenuBarVisible() {
        UserDefaults.standard.set(menuBarVisible, forKey: menuBarKey)
        log.debug("[Toolbar] menuBarVisible=\(menuBarVisible) saved")
    }
}
