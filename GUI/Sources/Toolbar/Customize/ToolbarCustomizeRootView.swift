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

    // MARK: - Current Toolbar (D-n-D reorder zone)
    private var currentToolbarSection: some View {
        sectionCard(
            title: "Current Toolbar",
            caption: helperText
        ) {
            currentToolbarStrip
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var currentToolbarStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
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
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 62)
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
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Available Items (palette)
    private var availableItemsSection: some View {
        sectionCard(
            title: "Available Items",
            caption: "Click to show or hide"
        ) {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 6)],
                    spacing: 6
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
                .padding(1)
            }
            .frame(minHeight: 150, maxHeight: .infinity)
            .onDrop(
                of: [.text],
                delegate: ToolbarCustPaletteDropDelegate(store: store, dragItem: $dragItem)
            )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
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
            ToolbarCustomizeDoneButton(title: "Done", systemImage: "checkmark") {
                log.debug("[ToolbarCustomize] Done action invoked")
                onDismiss()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DialogColors.stripe)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DialogColors.light.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(0.55), lineWidth: 0.75)
        )
    }
}

// MARK: - Toolbar Customize Done Button
private struct ToolbarCustomizeDoneButton: NSViewRepresentable {
    let title: String
    let systemImage: String
    let action: () -> Void

    func makeNSView(context: Context) -> ToolbarCustomizeDoneNSButton {
        let button = ToolbarCustomizeDoneNSButton(title: title, target: context.coordinator, action: #selector(Coordinator.performAction))
        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.setButtonType(.momentaryPushIn)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
        return button
    }

    func updateNSView(_ nsView: ToolbarCustomizeDoneNSButton, context: Context) {
        nsView.title = title
        nsView.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}

// MARK: - Toolbar Customize Done NSButton
private final class ToolbarCustomizeDoneNSButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
