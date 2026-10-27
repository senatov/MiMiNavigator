// ToolbarCustomizeRootView.swift
// MiMiNavigator
//
// Created by Claude on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Root view for toolbar customization dialog.
//   Compact macOS layout with a reorderable toolbar strip and command palette.

import AppKit
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
            availableItemsSection
            currentToolbarSection
            menuBarToggleRow
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
        sectionCard(title: "Current toolbar", caption: "Memory and Threads stay beside the centered build badge. Drag command buttons to reorder.") {
            currentToolbarStrip
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    private var currentToolbarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(store.customizableVisibleItems.filter(\.isStatusBadge)) { item in
                    ToolbarCustChip(item: item, isInToolbar: true, isDragging: false)
                }
                ToolbarCustChip(item: .buildInfo, isInToolbar: true, isDragging: false)
                Rectangle().fill(.primary.opacity(0.12)).frame(width: 1, height: 44).padding(.horizontal, 8)
                let items = store.customizableVisibleItems.filter { !$0.isStatusBadge }
                ForEach(Array(items.enumerated()), id: \.element) { index, item in
                    insertionZone(at: index)
                    ToolbarCustChip(item: item, isInToolbar: true, isDragging: dragItem == item)
                        .onDrag {
                            dragItem = item
                            return NSItemProvider(object: item.rawValue as NSString)
                        }
                }
                insertionZone(at: items.count)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 76)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(0.55), lineWidth: 0.75)
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
        sectionCard(title: "Menu Bar", caption: "Always available") {
            HStack(spacing: 10) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.menuBarVisible ? DialogColors.accent : Color.secondary.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(store.menuBarVisible ? DialogColors.accent.opacity(0.10) : Color.clear)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Menu Bar")
                        .font(.system(size: 12, weight: .medium))
                    Text("Files · Mark · Commands · Net · Show · Configuration")
                        .font(.system(size: 9))
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
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    // MARK: - Available Items (palette)
    private var availableItemsSection: some View {
        sectionCard(title: "Drag your favorite items into the toolbar…", caption: "Click an item to show or hide it") {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 88, maximum: 112), spacing: 12)],
                    spacing: 16
                ) {
                    ForEach(store.customizableItems) { item in
                        let isVisible = store.visibleIDs.contains(item)
                        if item.isStatusBadge {
                            ToolbarCustPaletteCell(item: item, isVisible: isVisible, onToggle: { store.toggleVisibility(item) })
                        } else {
                            ToolbarCustPaletteCell(item: item, isVisible: isVisible, onToggle: { store.toggleVisibility(item) })
                                .onDrag {
                                    dragItem = item
                                    return NSItemProvider(object: item.rawValue as NSString)
                                }
                        }
                    }
                }
                .padding(1)
            }
            .frame(height: 155)
            .onDrop(
                of: [.text],
                delegate: ToolbarCustPaletteDropDelegate(store: store, dragItem: $dragItem)
            )
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Footer
    private var footerButtons: some View {
        HStack(spacing: 12) {
            Text("Show")
                .font(.system(size: 12))
            Picker("Show", selection: $store.labelStyle) {
                ForEach(ToolbarLabelStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .labelsHidden()
            .frame(width: 130)
            Button("Use Default Set") { showResetConfirm = true }
                .buttonStyle(.plain)
                .font(.system(size: 11))
            Spacer()
            Button("Done") {
                log.debug("[ToolbarCustomize] Done action invoked")
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 82)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(6)
    }
}
