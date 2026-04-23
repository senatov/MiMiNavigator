// ToolbarCustDropDelegates.swift
// MiMiNavigator
//
// Created by Claude on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: D-n-D delegates for toolbar customization.
//   Reorder within Current Toolbar strip, append from palette.

import SwiftUI

// MARK: - Reorder within Current Toolbar
struct ToolbarCustReorderDelegate: DropDelegate {
    let target: ToolbarItemID
    let store: ToolbarStore
    @Binding var dragItem: ToolbarItemID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let from = dragItem, from != target else { return }
        // If dragged item is not visible yet — make it visible first
        if !store.visibleIDs.contains(from) {
            store.toggleVisibility(from)
        }
        guard
            let fromIdx = store.orderedIDs.firstIndex(of: from),
            let targetIdx = store.orderedIDs.firstIndex(of: target)
        else { return }
        let dest = targetIdx < fromIdx ? targetIdx : targetIdx + 1
        store.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: dest)
    }
}


// MARK: - Append to end of Current Toolbar
struct ToolbarCustAppendDelegate: DropDelegate {
    let store: ToolbarStore
    @Binding var dragItem: ToolbarItemID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let item = dragItem, !store.visibleIDs.contains(item) {
            store.toggleVisibility(item)
        }
        dragItem = nil
        return true
    }
}
