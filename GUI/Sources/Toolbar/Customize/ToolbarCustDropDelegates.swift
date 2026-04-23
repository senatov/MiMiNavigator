// ToolbarCustDropDelegates.swift
// MiMiNavigator
//
// Created by Claude on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: D-n-D delegates for toolbar customization.
//   Reorder within Current Toolbar strip using insertion slots.

import SwiftUI

// MARK: - Insert into Current Toolbar
struct ToolbarCustInsertDelegate: DropDelegate {
    let targetVisibleIndex: Int
    let store: ToolbarStore
    @Binding var dragItem: ToolbarItemID?
    @Binding var activeInsertionIndex: Int?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {
        activeInsertionIndex = targetVisibleIndex
    }

    func dropExited(info: DropInfo) {
        if activeInsertionIndex == targetVisibleIndex {
            activeInsertionIndex = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            dragItem = nil
            activeInsertionIndex = nil
        }
        guard let item = dragItem else { return false }
        if store.visibleIDs.contains(item) {
            store.moveVisibleItem(item, toVisibleIndex: targetVisibleIndex)
        } else {
            store.showItem(item, atVisibleIndex: targetVisibleIndex)
        }
        return true
    }
}
