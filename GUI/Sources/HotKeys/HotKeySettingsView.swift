// HotKeySettingsView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Settings panel for keyboard shortcuts — grouped by category, inline recorder

import SwiftUI

// MARK: - Hot Key Settings View
/// Full-featured keyboard shortcuts settings panel.
/// Shows all actions grouped by category with inline key recorders.
struct HotKeySettingsView: View {
    @State private var store = HotKeyStore.shared
    @State private var conflictAlert: ConflictInfo?
    @State private var showResetConfirmation = false
    @State private var filterText = ""
    @State private var selectedCategory: HotKeyCategory?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            header

            Divider()

            // MARK: - Content
            HSplitView {
                // Category sidebar
                categorySidebar
                    .frame(minWidth: 160, idealWidth: 180, maxWidth: 200)

                // Bindings list
                bindingsList
                    .frame(minWidth: 400)
            }

            Divider()

            // MARK: - Footer
            footer
        }
        .frame(minWidth: 640, minHeight: 480)
        .alert("Shortcut Conflict", isPresented: Binding(
            get: { conflictAlert != nil },
            set: { if !$0 { conflictAlert = nil } }
        )) {
            Button("Replace") {
                if let info = conflictAlert {
                    // Clear old binding, apply new
                    store.updateBinding(action: info.existingAction, keyCode: 0, modifiers: .none)
                    store.updateBinding(action: info.newAction, keyCode: info.keyCode, modifiers: info.modifiers)
                }
                conflictAlert = nil
            }
            Button("Cancel", role: .cancel) {
                conflictAlert = nil
            }
        } message: {
            if let info = conflictAlert {
                Text("'\(HotKeyBinding.keyName(for: info.keyCode))' is already assigned to '\(info.existingAction.displayName)'. Replace it?")
            }
        }
        .confirmationDialog("Reset All Shortcuts", isPresented: $showResetConfirmation) {
            Button("Reset to Defaults", role: .destructive) {
                store.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All keyboard shortcuts will be reset to factory defaults. This cannot be undone.")
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)

            Text("Keyboard Shortcuts")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            // Search filter
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                TextField("Filter…", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 140)
                if !filterText.isEmpty {
                    Button(action: { filterText = "" }) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Category Sidebar
    private var categorySidebar: some View {
        List(selection: $selectedCategory) {
            // "All" item
            Label("All Shortcuts", systemImage: "list.bullet")
                .tag(nil as HotKeyCategory?)
                .font(.system(size: 12))

            Divider()

            ForEach(HotKeyCategory.allCases) { category in
                Label {
                    HStack {
                        Text(category.displayName)
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(store.bindings(for: category).count)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                } icon: {
                    Image(systemName: category.icon)
                        .font(.system(size: 11))
                }
                .tag(category as HotKeyCategory?)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Bindings List
    private var bindingsList: some View {
        let filteredBindings = filteredAndSortedBindings

        return List {
            if filteredBindings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.quaternary)
                    Text("No matching shortcuts")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(groupedBindings(filteredBindings), id: \.category) { group in
                    Section(group.category.displayName) {
                        ForEach(group.bindings) { binding in
                            bindingRow(binding)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Binding Row
    private func bindingRow(_ binding: HotKeyBinding) -> some View {
        HStack(spacing: 12) {
            // Action name
            VStack(alignment: .leading, spacing: 2) {
                Text(binding.action.displayName)
                    .font(.system(size: 12))
            }

            Spacer()

            // Key recorder
            HotKeyRecorderView(binding: binding) { keyCode, modifiers in
                assignShortcut(action: binding.action, keyCode: keyCode, modifiers: modifiers)
            }

            // Reset single binding
            Button(action: { store.resetBinding(for: binding.action) }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reset to default")
            .opacity(isModified(binding) ? 1 : 0.3)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 12) {
            Button("Reset All to Defaults") {
                showResetConfirmation = true
            }
            .font(.system(size: 12))

            Spacer()

            Text("\(store.allBindings.count) shortcuts")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Logic

    private func assignShortcut(action: HotKeyAction, keyCode: UInt16, modifiers: HotKeyModifiers) {
        // Check for conflicts
        if let existing = store.conflictingAction(keyCode: keyCode, modifiers: modifiers, excluding: action) {
            conflictAlert = ConflictInfo(
                newAction: action,
                existingAction: existing,
                keyCode: keyCode,
                modifiers: modifiers
            )
        } else {
            store.updateBinding(action: action, keyCode: keyCode, modifiers: modifiers)
        }
    }

    private func isModified(_ binding: HotKeyBinding) -> Bool {
        guard let defaultBinding = HotKeyDefaults.bindingsByAction[binding.action] else { return true }
        return binding.keyCode != defaultBinding.keyCode || binding.modifiers != defaultBinding.modifiers
    }

    private var filteredAndSortedBindings: [HotKeyBinding] {
        var result = store.allBindings

        // Category filter
        if let cat = selectedCategory {
            result = result.filter { $0.action.category == cat }
        }

        // Text filter
        if !filterText.isEmpty {
            let query = filterText.lowercased()
            result = result.filter {
                $0.action.displayName.lowercased().contains(query)
                || $0.displayString.lowercased().contains(query)
                || $0.action.rawValue.lowercased().contains(query)
            }
        }

        return result
    }

    private func groupedBindings(_ list: [HotKeyBinding]) -> [BindingGroup] {
        let grouped = Dictionary(grouping: list) { $0.action.category }
        return HotKeyCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return BindingGroup(category: cat, bindings: items)
        }
    }
}

// MARK: - Supporting Types

private struct ConflictInfo {
    let newAction: HotKeyAction
    let existingAction: HotKeyAction
    let keyCode: UInt16
    let modifiers: HotKeyModifiers
}

private struct BindingGroup {
    let category: HotKeyCategory
    let bindings: [HotKeyBinding]
}

// MARK: - Preview
#Preview("Hot Key Settings") {
    HotKeySettingsView()
        .frame(width: 700, height: 500)
}
