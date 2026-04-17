// HotKeySettingsView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Root settings view for keyboard shortcuts.

import SwiftUI

struct HotKeySettingsView: View {
    @State private var store = HotKeyStore.shared
    @State private var conflictAlert: ConflictInfo?
    @State private var systemConflict: SystemConflictInfo?
    @State private var showResetConfirmation = false
    @State private var filterText = ""
    @State private var selectedCategory: HotKeyCategory?
    @State private var hoveredAction: HotKeyAction?
    @State private var showConflictsOnly = false

    private var groupedFilteredBindings: [BindingGroup] {
        groupedBindings(filteredBindings)
    }

    var body: some View {
        VStack(spacing: 0) {
            HotKeyTopToolbar(
                store: store,
                filterText: $filterText,
                showConflictsOnly: $showConflictsOnly
            )
            Divider()

            HSplitView {
                HotKeyCategorySidebar(
                    store: store,
                    selectedCategory: $selectedCategory,
                    categoryColor: categoryColor
                )
                .frame(minWidth: 140, idealWidth: 160, maxWidth: 180)

                HotKeyBindingsList(
                    groups: groupedFilteredBindings,
                    hoveredAction: hoveredAction,
                    categoryColor: categoryColor,
                    isConflicting: isConflicting,
                    isModified: isModified,
                    onAssignShortcut: assignShortcut,
                    onRemoveShortcut: removeShortcut,
                    onResetShortcut: resetBinding,
                    onHoverAction: updateHoveredAction
                )
                .frame(minWidth: 400)
            }

            Divider()
            HotKeyFooterBar(store: store, onResetAll: { showResetConfirmation = true })
        }
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Shortcut Conflict", isPresented: conflictAlertPresented) {
            Button("Replace") {
                guard let info = conflictAlert else { return }
                store.updateBinding(action: info.existingAction, keyCode: 0, modifiers: .none)
                store.updateBinding(action: info.newAction, keyCode: info.keyCode, modifiers: info.modifiers)
                conflictAlert = nil
            }
            Button("Cancel", role: .cancel) {
                conflictAlert = nil
            }
        } message: {
            if let info = conflictAlert {
                Text("'\(HotKeyBinding.keyName(for: info.keyCode))' is already assigned to '\(info.existingAction.displayName)'. Replace?")
            }
        }
        .confirmationDialog("Reset Shortcuts", isPresented: $showResetConfirmation) {
            Button("Reset to Total Commander", role: .destructive) {
                store.applyPreset(.totalCommander)
            }
            Button("Reset to Finder") {
                store.applyPreset(.finder)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a preset to reset all shortcuts.")
        }
        .sheet(isPresented: systemConflictPresented) {
            if let info = systemConflict {
                SystemConflictSheet(
                    info: info,
                    onSelect: { keyCode, modifiers in
                        store.updateBinding(action: info.action, keyCode: keyCode, modifiers: modifiers)
                        systemConflict = nil
                    },
                    onCancel: {
                        systemConflict = nil
                    }
                )
            }
        }
    }

    private var conflictAlertPresented: Binding<Bool> {
        Binding(
            get: { conflictAlert != nil },
            set: { if !$0 { conflictAlert = nil } }
        )
    }

    private var systemConflictPresented: Binding<Bool> {
        Binding(
            get: { systemConflict != nil },
            set: { if !$0 { systemConflict = nil } }
        )
    }

    private func categoryColor(_ category: HotKeyCategory?) -> Color {
        guard let category else { return .secondary }
        switch category {
        case .fileOperations: return .blue
        case .navigation: return .orange
        case .selection: return .green
        case .search: return .purple
        case .network: return .teal
        case .application: return .gray
        }
    }

    private func updateHoveredAction(_ action: HotKeyAction?) {
        hoveredAction = action
    }

    private func removeShortcut(for action: HotKeyAction) {
        store.updateBinding(action: action, keyCode: 0, modifiers: .none)
    }

    private func resetBinding(for action: HotKeyAction) {
        store.resetBinding(for: action)
    }

    private func assignShortcut(action: HotKeyAction, keyCode: UInt16, modifiers: HotKeyModifiers) {
        let result = ShortcutConflictValidator.validate(
            keyCode: keyCode,
            modifiers: modifiers,
            forAction: action
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
        case .appInternal(let existing):
            conflictAlert = ConflictInfo(
                newAction: action,
                existingAction: existing,
                keyCode: keyCode,
                modifiers: modifiers
            )
        case .none:
            break
        }
    }

    private func isModified(_ binding: HotKeyBinding) -> Bool {
        guard let defaultBinding = HotKeyDefaults.bindingsByAction[binding.action] else { return true }
        return binding.keyCode != defaultBinding.keyCode || binding.modifiers != defaultBinding.modifiers
    }

    private func isConflicting(_ binding: HotKeyBinding) -> Bool {
        guard binding.keyCode != 0 else { return false }
        return store.conflicts.contains { pair in
            pair.0.action == binding.action || pair.1.action == binding.action
        }
    }

    private var filteredBindings: [HotKeyBinding] {
        var result = store.allBindings

        if let selectedCategory {
            result = result.filter { $0.action.category == selectedCategory }
        }

        if showConflictsOnly {
            let conflictingActions = Set(store.conflicts.flatMap { [$0.0.action, $0.1.action] })
            result = result.filter { conflictingActions.contains($0.action) }
        }

        if !filterText.isEmpty {
            let query = filterText.lowercased()
            result = result.filter {
                $0.action.displayName.lowercased().contains(query)
                    || $0.displayString.lowercased().contains(query)
            }
        }

        return result
    }

    private func groupedBindings(_ bindings: [HotKeyBinding]) -> [BindingGroup] {
        let grouped = Dictionary(grouping: bindings) { $0.action.category }
        return HotKeyCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return BindingGroup(category: category, bindings: items)
        }
    }
}

#Preview {
    HotKeySettingsView()
        .frame(width: 700, height: 500)
}
