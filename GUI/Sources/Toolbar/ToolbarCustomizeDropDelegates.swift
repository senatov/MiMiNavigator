// ToolbarCustomizeDropDelegates.swift
// MiMiNavigator
//
// Created by Codex on 17.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

struct PreviewReorderDelegate: DropDelegate {
    let targetItem: ToolbarItemID
    let store: ToolbarStore
    @Binding var dragPreview: ToolbarItemID?
    @Binding var dragPool: ToolbarItemID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragPreview = nil
        dragPool = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        if let from = dragPreview, from != targetItem {
            let visibleItems = store.visibleItems
            guard
                let fromVisibleIndex = visibleItems.firstIndex(of: from),
                let targetVisibleIndex = visibleItems.firstIndex(of: targetItem),
                let fromGlobalIndex = store.orderedIDs.firstIndex(of: visibleItems[fromVisibleIndex]),
                let targetGlobalIndex = store.orderedIDs.firstIndex(of: visibleItems[targetVisibleIndex])
            else { return }

            store.move(
                fromOffsets: IndexSet(integer: fromGlobalIndex),
                toOffset: targetGlobalIndex < fromGlobalIndex ? targetGlobalIndex : targetGlobalIndex + 1
            )
        }

        if let poolItem = dragPool, poolItem != targetItem {
            if !store.visibleIDs.contains(poolItem) {
                store.toggleVisibility(poolItem)
            }

            guard
                let fromGlobalIndex = store.orderedIDs.firstIndex(of: poolItem),
                let targetGlobalIndex = store.orderedIDs.firstIndex(of: targetItem)
            else { return }

            store.move(
                fromOffsets: IndexSet(integer: fromGlobalIndex),
                toOffset: targetGlobalIndex < fromGlobalIndex ? targetGlobalIndex : targetGlobalIndex + 1
            )
            dragPool = nil
        }
    }
}

struct PreviewAppendDelegate: DropDelegate {
    let store: ToolbarStore
    @Binding var dragPool: ToolbarItemID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let item = dragPool, !store.visibleIDs.contains(item) {
            store.toggleVisibility(item)
        }
        dragPool = nil
        return true
    }
}
