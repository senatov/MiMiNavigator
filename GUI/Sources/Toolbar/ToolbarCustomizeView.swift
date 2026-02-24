// ToolbarCustomizeView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Toolbar customization dialog.
//   Preview strip (top) — drag to reorder visible buttons.
//   Palette grid (bottom) — click to toggle, drag to preview to add.
//   Menu bar toggle — show/hide the Files/Mark/Commands… menu row.
//   Filter field — narrows palette by label or help text.

import AppKit
import SwiftUI

// MARK: - Toolbar Customize View
struct ToolbarCustomizeView: View {

    @State private var store       = ToolbarStore.shared
    @State private var filterText  = ""
    @State private var showReset   = false
    @State private var dragPreview: ToolbarItemID? = nil
    @State private var dragPool:    ToolbarItemID? = nil

    var body: some View {
        VStack(spacing: 0) {
            TCV_Header()
            Divider()
            TCV_PreviewStrip(store: store, dragPreview: $dragPreview, dragPool: $dragPool)
            Divider()
            TCV_MenuBarRow(store: store)
            Divider()
            TCV_FilterField(text: $filterText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            Divider()
            TCV_Palette(store: store, filterText: filterText, dragPreview: $dragPreview, dragPool: $dragPool)
            Divider()
            TCV_Footer(store: store, showReset: $showReset)
        }
        .frame(width: 360, height: 500)
        .background(DialogColors.base)
        .confirmationDialog("Reset Toolbar", isPresented: $showReset) {
            Button("Reset to Defaults", role: .destructive) { store.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Toolbar order and visibility will be reset to factory defaults.")
        }
    }
}

// MARK: - Header
private struct TCV_Header: View {
    var body: some View {
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
}

// MARK: - Preview Strip
private struct TCV_PreviewStrip: View {
    let store: ToolbarStore
    @Binding var dragPreview: ToolbarItemID?
    @Binding var dragPool:    ToolbarItemID?

    var body: some View {
        VStack(spacing: 4) {
            Text("TOOLBAR PREVIEW")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            HStack(spacing: 6) {
                ForEach(store.visibleItems) { item in
                    TCV_PreviewButton(item: item, isDragging: dragPreview == item)
                        .onDrag {
                            dragPreview = item
                            dragPool    = nil
                            return NSItemProvider(object: item.rawValue as NSString)
                        }
                        .onDrop(of: [.text], delegate: PreviewReorderDelegate(
                            targetItem:  item,
                            store:       store,
                            dragPreview: $dragPreview,
                            dragPool:    $dragPool
                        ))
                }

                if dragPool != nil {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            Color.accentColor.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, dash: [4])
                        )
                        .frame(width: 36, height: 36)
                        .onDrop(of: [.text], delegate: PreviewAppendDelegate(
                            store:    store,
                            dragPool: $dragPool
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
}

// MARK: - Preview Button (single icon in strip)
private struct TCV_PreviewButton: View {
    let item:      ToolbarItemID
    let isDragging: Bool

    var body: some View {
        Image(systemName: item.systemImage)
            .font(.system(size: 15, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.accentColor)
            .frame(width: 36, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.10))
            )
            .opacity(isDragging ? 0.4 : 1.0)
            .help(item.helpText)
    }
}

// MARK: - Menu Bar Toggle Row
private struct TCV_MenuBarRow: View {
    let store: ToolbarStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 13))
                .foregroundStyle(store.menuBarVisible ? Color.accentColor : Color.secondary.opacity(0.5))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text("Show Menu Bar")
                    .font(.system(size: 13, weight: .medium))
                Text("Files · Mark · Commands · Net · Show · Configuration · Start · Help")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(get: { store.menuBarVisible },
                              set: { store.menuBarVisible = $0 })
            )
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(store.menuBarVisible ? Color.accentColor.opacity(0.04) : Color.clear)
    }
}

// MARK: - Filter Field
private struct TCV_FilterField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Filter buttons…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !text.isEmpty {
                Button { text = "" } label: {
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
}

// MARK: - Palette Grid
private struct TCV_Palette: View {
    let store:       ToolbarStore
    let filterText:  String
    @Binding var dragPreview: ToolbarItemID?
    @Binding var dragPool:    ToolbarItemID?

    // orderedIDs без fixed-элементов; menuBarToggle показывается отдельно внизу
    private var items: [ToolbarItemID] {
        let all = store.orderedIDs.filter { !$0.isFixed }
        guard !filterText.isEmpty else { return all }
        let q = filterText.lowercased()
        return all.filter { $0.label.lowercased().contains(q) || $0.helpText.lowercased().contains(q) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72, maximum: 88), spacing: 8)],
                spacing: 8
            ) {
                ForEach(items) { item in
                    TCV_PaletteCell(item: item, store: store)
                        .onDrag {
                            if store.visibleIDs.contains(item) {
                                dragPreview = nil
                                dragPool    = item
                            }
                            return NSItemProvider(object: item.rawValue as NSString)
                        }
                }
                // Fixed item — locked, always shown at end of palette
                TCV_PaletteCell(item: .menuBarToggle, store: store)
            }
            .padding(10)
        }
        .frame(maxHeight: .infinity)
        .background(DialogColors.base)
    }
}

// MARK: - Palette Cell
private struct TCV_PaletteCell: View {
    let item:  ToolbarItemID
    let store: ToolbarStore

    private var isVisible: Bool { item.isFixed || store.visibleIDs.contains(item) }
    private var isLastOne: Bool  { !item.isFixed && isVisible && store.visibleItems.count == 1 }

    var body: some View {
        Button {
            guard !item.isFixed, !isLastOne else { return }
            store.toggleVisibility(item)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
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
                    // Lock badge for fixed items; checkmark for toggleable
                    Image(systemName: item.isFixed ? "lock.fill" : (isVisible ? "checkmark.circle.fill" : "circle"))
                        .font(.system(size: 11))
                        .foregroundStyle(item.isFixed ? Color.orange : (isVisible ? Color.accentColor : Color.secondary.opacity(0.4)))
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
        .opacity(isVisible ? 1.0 : 0.6)
        .help(item.isFixed ? "Always in toolbar (cannot be removed)" :
              isLastOne   ? "At least one button must be visible" : item.helpText)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}

// MARK: - Footer
private struct TCV_Footer: View {
    let store:      ToolbarStore
    @Binding var showReset: Bool

    var body: some View {
        HStack {
            Button { showReset = true } label: {
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
private struct PreviewReorderDelegate: DropDelegate {
    let targetItem:  ToolbarItemID
    let store:       ToolbarStore
    @Binding var dragPreview: ToolbarItemID?
    @Binding var dragPool:    ToolbarItemID?

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragPreview = nil
        dragPool    = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        if let from = dragPreview, from != targetItem {
            let vis = store.visibleItems
            guard let fi = vis.firstIndex(of: from),
                  let ti = vis.firstIndex(of: targetItem),
                  let fg = store.orderedIDs.firstIndex(of: vis[fi]),
                  let tg = store.orderedIDs.firstIndex(of: vis[ti]) else { return }
            store.move(fromOffsets: IndexSet(integer: fg),
                       toOffset: tg < fg ? tg : tg + 1)
        }
        if let pool = dragPool, pool != targetItem {
            if !store.visibleIDs.contains(pool) { store.toggleVisibility(pool) }
            guard let fg = store.orderedIDs.firstIndex(of: pool),
                  let tg = store.orderedIDs.firstIndex(of: targetItem) else { return }
            store.move(fromOffsets: IndexSet(integer: fg),
                       toOffset: tg < fg ? tg : tg + 1)
            dragPool = nil
        }
    }
}

// MARK: - Drop Delegate: append from pool
private struct PreviewAppendDelegate: DropDelegate {
    let store:    ToolbarStore
    @Binding var dragPool: ToolbarItemID?

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .copy) }

    func performDrop(info: DropInfo) -> Bool {
        if let item = dragPool, !store.visibleIDs.contains(item) {
            store.toggleVisibility(item)
        }
        dragPool = nil
        return true
    }
}
