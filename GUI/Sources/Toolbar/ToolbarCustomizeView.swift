// ToolbarCustomizeView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Toolbar customization dialog — two-zone DnD layout.
//   Zone 1 (top): live toolbar preview strip — drag to reorder visible buttons.
//   Zone 2 (bottom): full button palette — drag to preview adds, drag away removes.
//   Visible buttons are active; hidden buttons are dimmed/disabled in the palette.
//   Minimum 1 button always visible. Filter narrows the palette.
//   Style: DialogColors palette, matches HotKeySettingsView aesthetic.

import AppKit
import SwiftUI

// MARK: - Toolbar Customize View
struct ToolbarCustomizeView: View {

    @State private var store = ToolbarStore.shared
    @State private var filterText = ""
    @State private var showResetConfirm = false

    /// ID currently being dragged from the palette (pool → preview drag)
    @State private var draggingFromPool: ToolbarItemID? = nil
    /// ID currently being dragged from the preview strip (reorder)
    @State private var draggingFromPreview: ToolbarItemID? = nil

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            previewStrip
            Divider()
            menuBarToggleRow
            Divider()
            filterField
                .padding(.horizontal, 10)
                .padding(.top, 7)
                .padding(.bottom, 5)
            Divider()
            paletteGrid
            Divider()
            footerBar
        }
        .frame(width: 360, height: 490)
        .background(DialogColors.base)
        .confirmationDialog("Reset Toolbar", isPresented: $showResetConfirm) {
            Button("Reset to Defaults", role: .destructive) { store.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Toolbar order and visibility will be reset to factory defaults.")
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
            Text("Customize Toolbar")
                .font(.system(.subheadline, design: .default, weight: .semibold))
            Spacer()
            Text("Drag to reorder • click to toggle")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DialogColors.stripe)
    }

    // MARK: - Zone 1: Live Preview Strip
    /// Shows only visible buttons in their current order.
    /// Drag within the strip = reorder. Drop from palette = add. Drag out = remove.
    private var previewStrip: some View {
        VStack(spacing: 4) {
            Text("TOOLBAR PREVIEW")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            HStack(spacing: 6) {
                ForEach(store.visibleItems) { item in
                    previewButton(item)
                        .onDrag {
                            draggingFromPreview = item
                            draggingFromPool = nil
                            return NSItemProvider(object: item.rawValue as NSString)
                        }
                        .onDrop(of: [.text], delegate: PreviewDropDelegate(
                            item: item,
                            store: store,
                            draggingFromPreview: $draggingFromPreview,
                            draggingFromPool: $draggingFromPool
                        ))
                }

                // Drop zone placeholder when dragging from pool
                if draggingFromPool != nil {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .frame(width: 36, height: 36)
                        .onDrop(of: [.text], delegate: PreviewAppendDropDelegate(
                            store: store,
                            draggingFromPool: $draggingFromPool
                        ))
                }

                if store.visibleItems.isEmpty {
                    Text("Drop buttons here")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .frame(minHeight: 52)
            .background(DialogColors.light)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    /// Single button in the preview strip
    private func previewButton(_ item: ToolbarItemID) -> some View {
        let isBeingDragged = draggingFromPreview == item
        return VStack(spacing: 2) {
            Image(systemName: item.systemImage)
                .font(.system(size: 15, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.10))
                )
        }
        .opacity(isBeingDragged ? 0.4 : 1.0)
        .help(item.helpText)
    }

    // MARK: - Menu Bar toggle row
    private var menuBarToggleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: store.menuBarVisible ? "menubar.rectangle" : "menubar.rectangle")
                .font(.system(size: 13))
                .foregroundStyle(store.menuBarVisible ? Color.accentColor : Color.secondary.opacity(0.5))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 1) {
                Text("Show Menu Bar")
                    .font(.system(size: 13, weight: .medium))
                Text("Files, Mark, Commands, Net, Show, Configuration, Start, Help")
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
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(store.menuBarVisible ? Color.accentColor.opacity(0.04) : Color.clear)
    }

    // MARK: - Filter field
    private var filterField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Filter buttons…", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !filterText.isEmpty {
                Button { filterText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Zone 2: Palette Grid
    /// All buttons in their stored order. Visible = active, hidden = dimmed.
    /// Drag from palette → preview strip adds. Click checkbox toggles.
    private var paletteGrid: some View {
        let items = filteredPaletteItems
        return ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 88), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    paletteCell(item)
                        .onDrag {
                            let isVisible = store.visibleIDs.contains(item)
                            if isVisible {
                                draggingFromPreview = nil
                                draggingFromPool = item
                            }
                            return NSItemProvider(object: item.rawValue as NSString)
                        }
                }
            }
            .padding(10)
        }
        .frame(maxHeight: .infinity)
        .background(DialogColors.base)
    }

    private var filteredPaletteItems: [ToolbarItemID] {
        guard !filterText.isEmpty else { return store.orderedIDs }
        let q = filterText.lowercased()
        return store.orderedIDs.filter {
            $0.label.lowercased().contains(q) ||
            $0.helpText.lowercased().contains(q) ||
            $0.rawValue.lowercased().contains(q)
        }
    }

    /// Single cell in the palette grid
    private func paletteCell(_ item: ToolbarItemID) -> some View {
        let isVisible = store.visibleIDs.contains(item)
        let isLastVisible = isVisible && store.visibleItems.count == 1
        let isDimmed = !isVisible

        return Button {
            guard !isLastVisible else { return }  // enforce minimum 1
            store.toggleVisibility(item)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Icon background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isVisible ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.06))
                        .frame(width: 44, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isVisible ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15),
                                    lineWidth: 0.8
                                )
                        )

                    Image(systemName: item.systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isVisible ? Color.accentColor : Color.secondary.opacity(0.45))
                        .frame(width: 44, height: 36)

                    // Visibility badge
                    Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundStyle(isVisible ? Color.accentColor : Color.secondary.opacity(0.4))
                        .offset(x: 5, y: -5)
                }

                Text(item.label)
                    .font(.system(size: 10, weight: isVisible ? .medium : .regular))
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 68)
            }
        }
        .buttonStyle(.plain)
        .opacity(isDimmed ? 0.6 : 1.0)
        .help(isLastVisible ? "At least one button must be visible" : item.helpText)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }

    // MARK: - Footer
    private var footerBar: some View {
        HStack {
            Button {
                showResetConfirm = true
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12))
            }
            .controlSize(.small)

            Spacer()

            Text("\(store.visibleItems.count) of \(store.orderedIDs.count) shown")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DialogColors.stripe)
    }
}

// MARK: - Drop Delegate: reorder within preview strip
private struct PreviewDropDelegate: DropDelegate {
    let item: ToolbarItemID
    let store: ToolbarStore
    @Binding var draggingFromPreview: ToolbarItemID?
    @Binding var draggingFromPool: ToolbarItemID?

    func performDrop(info: DropInfo) -> Bool {
        draggingFromPreview = nil
        draggingFromPool = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        // Reorder: move dragged preview item to this position
        if let from = draggingFromPreview, from != item {
            let visibles = store.visibleItems
            guard let fromIdx = visibles.firstIndex(of: from),
                  let toIdx   = visibles.firstIndex(of: item) else { return }

            // Map visible indices back to orderedIDs indices
            guard let fromGlobal = store.orderedIDs.firstIndex(of: visibles[fromIdx]),
                  let toGlobal   = store.orderedIDs.firstIndex(of: visibles[toIdx]) else { return }

            store.move(fromOffsets: IndexSet(integer: fromGlobal),
                       toOffset: toGlobal < fromGlobal ? toGlobal : toGlobal + 1)
        }

        // Pool → preview: make visible and insert before this item
        if let poolItem = draggingFromPool, poolItem != item {
            if !store.visibleIDs.contains(poolItem) {
                store.toggleVisibility(poolItem)
            }
            // Reorder to be before `item`
            guard let fromGlobal = store.orderedIDs.firstIndex(of: poolItem),
                  let toGlobal   = store.orderedIDs.firstIndex(of: item) else { return }
            store.move(fromOffsets: IndexSet(integer: fromGlobal),
                       toOffset: toGlobal < fromGlobal ? toGlobal : toGlobal + 1)
            draggingFromPool = nil
        }
    }
}

// MARK: - Drop Delegate: append from pool to end of preview strip
private struct PreviewAppendDropDelegate: DropDelegate {
    let store: ToolbarStore
    @Binding var draggingFromPool: ToolbarItemID?

    func performDrop(info: DropInfo) -> Bool {
        if let item = draggingFromPool, !store.visibleIDs.contains(item) {
            store.toggleVisibility(item)
        }
        draggingFromPool = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }
}
