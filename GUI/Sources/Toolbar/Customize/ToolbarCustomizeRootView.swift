// ToolbarCustomizeRootView.swift
// MiMiNavigator
//
// Created by Claude on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Root view for toolbar customization dialog.
//   Classic macOS style: "Current Toolbar" strip on top (D-n-D reorder, drag out to remove),
//   "Available Items" palette below (drag into Current to add).
//   Same button style as Settings. Single-screen dialog.

import SwiftUI

// MARK: - Toolbar Customize Root View
struct ToolbarCustomizeRootView: View {

    let onDismiss: () -> Void
    @State private var store = ToolbarStore.shared
    @State private var showResetConfirm = false
    @State private var dragItem: ToolbarItemID? = nil
    @State private var activeInsertionIndex: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            currentToolbarSection
            Divider()
            menuBarToggleRow
            Divider()
            availableItemsSection
            Divider()
            footerButtons
        }
        .background(DialogColors.base)
        .confirmationDialog("Reset Toolbar", isPresented: $showResetConfirm) {
            Button("Reset to Defaults", role: .destructive) { store.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Toolbar order and visibility will be reset to factory defaults.")
        }
    }

    // MARK: - Current Toolbar (D-n-D reorder zone)
    private var currentToolbarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CURRENT TOOLBAR")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)

            currentToolbarStrip
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Text("Drag to reorder · drag out to remove")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
        }
        .background(DialogColors.light)
    }

    private var currentToolbarStrip: some View {
        HStack(spacing: 8) {
            let items = store.visibleItems
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                insertionZone(at: index)
                ToolbarCustChip(item: item, isInToolbar: true, isDragging: dragItem == item)
                    .onDrag {
                        dragItem = item
                        return NSItemProvider(object: item.rawValue as NSString)
                    }
            }
            insertionZone(at: items.count)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 48)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
        .onDrop(of: [.text], isTargeted: nil) { _ in
            dragItem = nil
            activeInsertionIndex = nil
            return false
        }
    }

    @ViewBuilder
    private func insertionZone(at index: Int) -> some View {
        ToolbarCustInsertionDropZone(isActive: activeInsertionIndex == index)
            .onDrop(
                of: [.text],
                delegate: ToolbarCustInsertDelegate(
                    targetVisibleIndex: index,
                    store: store,
                    dragItem: $dragItem,
                    activeInsertionIndex: $activeInsertionIndex
                )
            )
    }

    // MARK: - Menu Bar Toggle
    private var menuBarToggleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 14))
                .foregroundStyle(store.menuBarVisible ? Color.accentColor : Color.secondary.opacity(0.5))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Show Menu Bar")
                    .font(.system(size: 13, weight: .medium))
                Text("Files · Mark · Commands · Net · Show · Configuration")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.menuBarVisible },
                set: { store.menuBarVisible = $0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(store.menuBarVisible ? Color.accentColor.opacity(0.04) : Color.clear)
    }

    // MARK: - Available Items (palette)
    private var availableItemsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AVAILABLE ITEMS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 8)
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(store.orderedIDs.filter { !$0.isFixed }) { item in
                        let isVisible = store.visibleIDs.contains(item)
                        ToolbarCustPaletteCell(
                            item: item,
                            isVisible: isVisible,
                            onToggle: { store.toggleVisibility(item) }
                        )
                        .onDrag {
                            dragItem = item
                            return NSItemProvider(object: item.rawValue as NSString)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .frame(maxHeight: .infinity)
        }
        .background(DialogColors.base)
    }

    // MARK: - Footer
    private var footerButtons: some View {
        HStack(spacing: 12) {
            DownToolbarButtonView(title: "Reset", systemImage: "arrow.counterclockwise") {
                showResetConfirm = true
            }
            Spacer()
            Text("\(store.visibleItems.count) of \(store.orderedIDs.filter { !$0.isFixed }.count) shown")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            DownToolbarButtonView(title: "Done", systemImage: "checkmark") {
                onDismiss()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DialogColors.stripe)
    }
}
