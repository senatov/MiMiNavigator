// ToolbarCustomizeRootView.swift
// MiMiNavigator
//
// Created by Claude on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Root view for toolbar customization dialog.
//   Refined macOS layout with card-based sections, explicit hierarchy,
//   reorderable current toolbar strip, and palette drop-to-remove behavior.

import SwiftUI

// MARK: - Toolbar Customize Root View
struct ToolbarCustomizeRootView: View {

    let onDismiss: () -> Void
    @State private var store = ToolbarStore.shared
    @State private var showResetConfirm = false
    @State private var dragItem: ToolbarItemID? = nil
    @State private var activeInsertionIndex: Int? = nil

    private var visibleCountText: String {
        "\(store.customizableVisibleItems.count) of \(store.customizableItems.count) shown"
    }

    private var helperText: String {
        dragItem == nil
            ? "Drag to reorder. Drop into Available Items to remove."
            : "Drop between items to insert. Drop below to hide."
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            currentToolbarSection
            menuBarToggleRow
            availableItemsSection
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Customize Toolbar")
                .font(.system(size: 20, weight: .semibold))
            Text("Reorder your main actions, hide rarely used buttons, and keep the menu bar toggle separate.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(DialogColors.base)
    }

    // MARK: - Current Toolbar (D-n-D reorder zone)
    private var currentToolbarSection: some View {
        sectionCard(
            title: "Current Toolbar",
            caption: helperText
        ) {
            currentToolbarStrip
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private var currentToolbarStrip: some View {
        HStack(spacing: 8) {
            let items = store.customizableVisibleItems
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
        .frame(minHeight: 86)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(0.4), lineWidth: 0.5)
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
        sectionCard(title: "Always Available", caption: "This control stays outside the customizable button strip.") {
            HStack(spacing: 12) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.menuBarVisible ? DialogColors.accent : Color.secondary.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(store.menuBarVisible ? DialogColors.accent.opacity(0.12) : Color.white.opacity(0.24))
                    )

                VStack(alignment: .leading, spacing: 2) {
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
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Available Items (palette)
    private var availableItemsSection: some View {
        sectionCard(
            title: "Available Items",
            caption: "Click to show or hide. You can also drag items here to remove them from the toolbar."
        ) {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 108, maximum: 124), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(store.customizableItems) { item in
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
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            }
            .frame(minHeight: 220, maxHeight: .infinity)
            .onDrop(
                of: [.text],
                delegate: ToolbarCustPaletteDropDelegate(store: store, dragItem: $dragItem)
            )
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Footer
    private var footerButtons: some View {
        HStack(spacing: 12) {
            DownToolbarButtonView(title: "Reset", systemImage: "arrow.counterclockwise") {
                showResetConfirm = true
            }
            Spacer()
            Text(visibleCountText)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            DownToolbarButtonView(title: "Done", systemImage: "checkmark") {
                onDismiss()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(DialogColors.stripe)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DialogColors.light.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(0.42), lineWidth: 0.5)
        )
    }
}
