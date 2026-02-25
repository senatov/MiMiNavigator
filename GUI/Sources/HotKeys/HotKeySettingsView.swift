// HotKeySettingsView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Settings panel for keyboard shortcuts — grouped by category, inline recorder.
//   Visual style matches NetworkNeighborhoodView: SF Pro Display 14, DialogColors palette.

import SwiftUI

// MARK: - Hot Key Settings View
struct HotKeySettingsView: View {
    /// When embedded in Settings, skip outer frame constraints
    var embedded: Bool = false

    @State private var store = HotKeyStore.shared
    @State private var themeStore = ColorThemeStore.shared
    @State private var conflictAlert: ConflictInfo?
    @State private var systemConflict: SystemConflictInfo?
    @State private var showResetConfirmation = false
    @State private var filterText = ""
    @State private var selectedCategory: HotKeyCategory?
    @State private var hoveredAction: HotKeyAction?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            HSplitView {
                categorySidebar
                    .frame(minWidth: 160, idealWidth: 180, maxWidth: 200)
                bindingsList
                    .frame(minWidth: 420)
            }
            Divider()
            footerBar
        }
        .frame(
            minWidth: embedded ? 0 : 660,
            maxWidth: .infinity,
            minHeight: embedded ? 0 : 480,
            maxHeight: .infinity
        )
        .background(DialogColors.base)
        .alert("Shortcut Conflict", isPresented: Binding(
            get: { conflictAlert != nil },
            set: { if !$0 { conflictAlert = nil } }
        )) {
            Button("Replace") {
                if let info = conflictAlert {
                    store.updateBinding(action: info.existingAction, keyCode: 0, modifiers: .none)
                    store.updateBinding(action: info.newAction, keyCode: info.keyCode, modifiers: info.modifiers)
                }
                conflictAlert = nil
            }
            Button("Cancel", role: .cancel) { conflictAlert = nil }
        } message: {
            if let info = conflictAlert {
                Text("'\(HotKeyBinding.keyName(for: info.keyCode))' is already assigned to '\(info.existingAction.displayName)'. Replace it?")
            }
        }
        .confirmationDialog("Reset All Shortcuts", isPresented: $showResetConfirmation) {
            Button("Reset to Defaults", role: .destructive) { store.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All keyboard shortcuts will be reset to factory defaults. This cannot be undone.")
        }
        // MARK: - System Shortcut Conflict Sheet
        .sheet(isPresented: Binding(
            get: { systemConflict != nil },
            set: { if !$0 { systemConflict = nil } }
        )) {
            if let info = systemConflict {
                SystemConflictSheet(
                    info: info,
                    onSelect: { keyCode, modifiers in
                        store.updateBinding(action: info.action, keyCode: keyCode, modifiers: modifiers)
                        systemConflict = nil
                    },
                    onCancel: { systemConflict = nil }
                )
            }
        }
    }

    // MARK: - Header (Network Neighborhood style)
    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 16))
                .foregroundStyle(.orange)
            Text("Keyboard Shortcuts")
                .font(.system(.subheadline, design: .default, weight: .medium))
            Spacer()
            filterField
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DialogColors.stripe)
    }

    // MARK: - Filter field
    private var filterField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Filter…", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .default))
                .frame(width: 140)
            if !filterText.isEmpty {
                Button { filterText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Category Sidebar
    private var categorySidebar: some View {
        VStack(spacing: 0) {
            categoryButton(label: "All Shortcuts", icon: "list.bullet", category: nil)
            Divider().padding(.horizontal, 8).padding(.vertical, 4)
            ForEach(HotKeyCategory.allCases) { category in
                categoryButton(
                    label: category.displayName,
                    icon: category.icon,
                    category: category,
                    count: store.bindings(for: category).count
                )
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .background(DialogColors.base)
    }

    private func categoryButton(label: String, icon: String, category: HotKeyCategory?, count: Int? = nil) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = category }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white : categoryColor(category))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13, design: .default))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                if let c = count {
                    Text("\(c)")
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.gray.opacity(0.5))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func categoryColor(_ category: HotKeyCategory?) -> Color {
        guard let cat = category else { return .secondary }
        switch cat {
        case .fileOperations: return .blue
        case .navigation:     return .orange
        case .selection:      return .green
        case .search:         return .purple
        case .application:    return .gray
        }
    }

    // MARK: - Bindings List
    private var bindingsList: some View {
        let filtered = filteredAndSortedBindings
        return ScrollView {
            LazyVStack(spacing: 0) {
                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedBindings(filtered), id: \.category) { group in
                        sectionHeader(group.category)
                        ForEach(group.bindings) { binding in
                            bindingRow(binding)
                            Divider().padding(.leading, 36)
                        }
                    }
                }
            }
        }
        .background(DialogColors.base)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 40)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
            Text("No matching shortcuts")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ category: HotKeyCategory) -> some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.system(size: 11))
                .foregroundStyle(categoryColor(category))
            Text(category.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 4)
    }

    // MARK: - Binding Row (Network Neighborhood row style)
    private func bindingRow(_ binding: HotKeyBinding) -> some View {
        let isHovered = hoveredAction == binding.action
        return HStack(spacing: 10) {
            // Action name
            Text(binding.action.displayName)
                .font(.system(size: 14, design: .default))
                .lineLimit(1)

            Spacer()

            // Key recorder
            HotKeyRecorderView(binding: binding) { keyCode, modifiers in
                assignShortcut(action: binding.action, keyCode: keyCode, modifiers: modifiers)
            }

            // Reset single binding
            if isHovered && isModified(binding) {
                Button { store.resetBinding(for: binding.action) } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(isHovered ? Color.accentColor.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hoveredAction = $0 ? binding.action : nil }
    }

    // MARK: - Footer
    private var footerBar: some View {
        HStack(spacing: 12) {
            Button {
                showResetConfirmation = true
            } label: {
                Label("Reset All", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12))
            }
            .controlSize(.small)

            Spacer()

            Text("\(store.allBindings.count) shortcuts")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DialogColors.stripe)
    }

    // MARK: - Logic

    private func assignShortcut(action: HotKeyAction, keyCode: UInt16, modifiers: HotKeyModifiers) {
        let result = ShortcutConflictValidator.validate(
            keyCode: keyCode, modifiers: modifiers, forAction: action
        )

        guard result.hasConflict else {
            store.updateBinding(action: action, keyCode: keyCode, modifiers: modifiers)
            return
        }

        switch result.conflict {
        case .systemReserved:
            systemConflict = SystemConflictInfo(
                action: action,
                description: result.conflictDescription,
                suggestions: result.suggested
            )
        case .appInternal(let existingAction):
            conflictAlert = ConflictInfo(
                newAction: action, existingAction: existingAction,
                keyCode: keyCode, modifiers: modifiers
            )
        case .none:
            break
        }
    }

    private func isModified(_ binding: HotKeyBinding) -> Bool {
        guard let def = HotKeyDefaults.bindingsByAction[binding.action] else { return true }
        return binding.keyCode != def.keyCode || binding.modifiers != def.modifiers
    }

    private var filteredAndSortedBindings: [HotKeyBinding] {
        var result = store.allBindings
        if let cat = selectedCategory {
            result = result.filter { $0.action.category == cat }
        }
        if !filterText.isEmpty {
            let q = filterText.lowercased()
            result = result.filter {
                $0.action.displayName.lowercased().contains(q)
                || $0.displayString.lowercased().contains(q)
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
