// ContextMenuOptionCoordinator.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Finder-style live Option expansion for tracked AppKit context menus.

import AppKit

// MARK: - Context Menu Option Coordinator
@MainActor
final class ContextMenuOptionCoordinator {
    static let shared = ContextMenuOptionCoordinator()
    private let monitors = PopupEventMonitors()
    private static let alternateIdentifierPrefix = "MiMi.ContextMenu.Option."

    private init() {}

    // MARK: - Monitoring
    func start() {
        monitors.installContextMenuPreparation { [weak self] menu in
            self?.prepareAlternates(in: menu)
        }
    }

    // MARK: - Alternate Preparation
    private func prepareAlternates(in menu: NSMenu) {
        guard !hasPreparedAlternates(in: menu) else { return }
        guard let match = operationsItem(in: menu) else { return }
        guard let submenu = match.item.submenu else { return }
        let alternateItems = submenu.items.enumerated().compactMap { offset, source -> NSMenuItem? in
            guard let item = source.copy() as? NSMenuItem else { return nil }
            item.isAlternate = true
            item.keyEquivalent = match.item.keyEquivalent
            item.keyEquivalentModifierMask = [.option]
            item.identifier = NSUserInterfaceItemIdentifier(Self.alternateIdentifierPrefix + String(offset))
            return item
        }
        for (offset, item) in alternateItems.enumerated() {
            menu.insertItem(item, at: match.index + 1 + offset)
        }
    }

    // MARK: - Operations Item Lookup
    private func operationsItem(in menu: NSMenu) -> (item: NSMenuItem, index: Int)? {
        for (index, item) in menu.items.enumerated() {
            guard item.submenu != nil else { continue }
            if item.title.contains("File Operations") || item.title.contains("Folder Operations") {
                return (item, index)
            }
        }
        return nil
    }

    // MARK: - Preparation State
    private func hasPreparedAlternates(in menu: NSMenu) -> Bool {
        menu.items.contains { item in
            item.identifier?.rawValue.hasPrefix(Self.alternateIdentifierPrefix) == true
        }
    }
}
