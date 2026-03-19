// HotKeySettingsView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Settings panel for keyboard shortcuts — Xcode-style UI with presets,
//   conflict detection, search filter, and inline editing.

import SwiftUI

// MARK: - Hot Key Settings View
struct HotKeySettingsView: View {
    @State private var store = HotKeyStore.shared
    @State private var conflictAlert: ConflictInfo?
    @State private var systemConflict: SystemConflictInfo?
    @State private var showResetConfirmation = false
    @State private var filterText = ""
    @State private var selectedCategory: HotKeyCategory?
    @State private var hoveredAction: HotKeyAction?
    @State private var showConflictsOnly = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Toolbar ──
            topToolbar
            Divider()
            
            // ── Main Content ──
            HSplitView {
                categorySidebar
                    .frame(minWidth: 140, idealWidth: 160, maxWidth: 180)
                bindingsList
                    .frame(minWidth: 400)
            }
            
            Divider()
            footerBar
        }
        .frame(minWidth: 640, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
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
                Text("'\(HotKeyBinding.keyName(for: info.keyCode))' is already assigned to '\(info.existingAction.displayName)'. Replace?")
            }
        }
        .confirmationDialog("Reset Shortcuts", isPresented: $showResetConfirmation) {
            Button("Reset to Total Commander", role: .destructive) { store.applyPreset(.totalCommander) }
            Button("Reset to Finder") { store.applyPreset(.finder) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a preset to reset all shortcuts.")
        }
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

    // MARK: - Top Toolbar (Xcode-style)
    private var topToolbar: some View {
        HStack(spacing: 12) {
            // Preset picker
            Menu {
                ForEach(HotKeyPreset.allCases.filter { $0 != .custom }) { preset in
                    Button {
                        store.applyPreset(preset)
                    } label: {
                        HStack {
                            Image(systemName: preset.icon)
                            Text(preset.displayName)
                            if store.currentPreset == preset {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Shortcut Set")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: store.currentPreset.icon)
                            .font(.system(size: 11))
                        Text(store.currentPreset.displayName)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Spacer()
            
            // Conflicts indicator
            if store.hasConflicts {
                Button {
                    showConflictsOnly.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(store.conflicts.count) conflicts")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(showConflictsOnly ? Color.orange.opacity(0.2) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Filter field
            filterField
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }

    // MARK: - Filter Field
    /// Search input field — filters shortcuts by name or key combination
    private var filterField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            
            TextField("Filter", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 120)
            
            // Clear button when filter is active
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
        .background(fieldBackground)
    }
    
    /// Reusable field background style
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
            )
    }

    // MARK: - Category Sidebar
    /// Left sidebar with category list and counts
    private var categorySidebar: some View {
        VStack(spacing: 0) {
            // "All" category at top
            categoryRow(
                label: "All",
                icon: "list.bullet",
                category: nil,
                count: store.allBindings.count
            )
            
            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            
            // Individual categories
            ForEach(HotKeyCategory.allCases) { cat in
                categoryRow(
                    label: cat.displayName,
                    icon: cat.icon,
                    category: cat,
                    count: store.bindings(for: cat).count
                )
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }
    
    /// Single category row with selection highlight
    private func categoryRow(label: String, icon: String, category: HotKeyCategory?, count: Int) -> some View {
        let isSelected = selectedCategory == category
        
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white : categoryColor(category))
                    .frame(width: 16)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }
    
    /// Category accent color for icons
    private func categoryColor(_ cat: HotKeyCategory?) -> Color {
        guard let cat else { return .secondary }
        switch cat {
        case .fileOperations: return .blue
        case .navigation:     return .orange
        case .selection:      return .green
        case .search:         return .purple
        case .network:        return .teal
        case .application:    return .gray
        }
    }

    // MARK: - Bindings List
    /// Main content area — scrollable list of shortcut bindings
    private var bindingsList: some View {
        let filtered = filteredBindings
        
        return ScrollView {
            LazyVStack(spacing: 0) {
                if filtered.isEmpty {
                    emptyStateView
                } else {
                    ForEach(groupedBindings(filtered), id: \.category) { group in
                        sectionHeader(group.category)
                        ForEach(group.bindings) { binding in
                            bindingRow(binding)
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    /// Empty state when filter matches nothing
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 60)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No matching shortcuts")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Section header for category groups
    private func sectionHeader(_ category: HotKeyCategory) -> some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.system(size: 10))
                .foregroundStyle(categoryColor(category))
            Text(category.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Binding Row
    /// Single shortcut row with inline recorder and conflict indicator
    private func bindingRow(_ binding: HotKeyBinding) -> some View {
        let isHovered = hoveredAction == binding.action
        let hasConflict = isConflicting(binding)
        let hasBinding = binding.keyCode != 0
        
        return HStack(spacing: 10) {
            // Conflict indicator (red dot)
            if hasConflict {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            
            // Action display name
            Text(binding.action.displayName)
                .font(.system(size: 12))
                .foregroundStyle(hasConflict ? .red : .primary)
                .lineLimit(1)
            
            Spacer()
            
            // Inline key recorder
            HotKeyRecorderView(binding: binding) { keyCode, modifiers in
                assignShortcut(action: binding.action, keyCode: keyCode, modifiers: modifiers)
            }
            
            // Delete binding button (minus) — always visible when has binding
            if hasBinding {
                Button {
                    store.updateBinding(action: binding.action, keyCode: 0, modifiers: .none)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove shortcut")
            } else {
                // Spacer to keep alignment when no binding
                Color.clear.frame(width: 14)
            }
            
            // Reset button (visible on hover if modified)
            if isHovered && isModified(binding) {
                resetButton(for: binding.action)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(rowBackground(isHovered: isHovered, hasConflict: hasConflict))
        .contentShape(Rectangle())
        .onHover { hoveredAction = $0 ? binding.action : nil }
    }
    
    /// Row background color based on state
    private func rowBackground(isHovered: Bool, hasConflict: Bool) -> Color {
        if hasConflict { return Color.red.opacity(0.08) }
        if isHovered { return Color.accentColor.opacity(0.06) }
        return Color.clear
    }
    
    /// Reset single binding button
    private func resetButton(for action: HotKeyAction) -> some View {
        Button { store.resetBinding(for: action) } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Reset to default")
    }

    // MARK: - Footer Bar
    /// Bottom bar with reset button, F5 warning, and shortcut count
    private var footerBar: some View {
        HStack(spacing: 12) {
            // Reset dropdown
            Menu {
                Button("Total Commander") { store.applyPreset(.totalCommander) }
                Button("Finder") { store.applyPreset(.finder) }
            } label: {
                Label("Reset All…", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Spacer()
            
            // F5 warning
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("F5 is reserved by macOS")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .help("macOS uses F5 for 'Move focus to toolbar'. To use F5, disable it in System Preferences → Keyboard → Shortcuts → Keyboard.")
            
            Spacer()
            
            // Shortcut count
            Text("\(store.allBindings.count) shortcuts")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Logic Helpers
    
    /// Assign shortcut with conflict validation
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
    
    /// Check if binding differs from default
    private func isModified(_ binding: HotKeyBinding) -> Bool {
        guard let def = HotKeyDefaults.bindingsByAction[binding.action] else { return true }
        return binding.keyCode != def.keyCode || binding.modifiers != def.modifiers
    }
    
    /// Check if binding has a duplicate key assignment
    private func isConflicting(_ binding: HotKeyBinding) -> Bool {
        guard binding.keyCode != 0 else { return false }
        return store.conflicts.contains { pair in
            pair.0.action == binding.action || pair.1.action == binding.action
        }
    }

    // MARK: - Filtering & Grouping
    
    /// Apply search filter and category filter
    private var filteredBindings: [HotKeyBinding] {
        var result = store.allBindings
        
        // Category filter
        if let cat = selectedCategory {
            result = result.filter { $0.action.category == cat }
        }
        
        // Conflicts-only filter
        if showConflictsOnly {
            let conflictingActions = Set(store.conflicts.flatMap { [$0.0.action, $0.1.action] })
            result = result.filter { conflictingActions.contains($0.action) }
        }
        
        // Text filter
        if !filterText.isEmpty {
            let query = filterText.lowercased()
            result = result.filter {
                $0.action.displayName.lowercased().contains(query) ||
                $0.displayString.lowercased().contains(query)
            }
        }
        
        return result
    }
    
    /// Group bindings by category for section display
    private func groupedBindings(_ list: [HotKeyBinding]) -> [BindingGroup] {
        let grouped = Dictionary(grouping: list) { $0.action.category }
        return HotKeyCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return BindingGroup(category: cat, bindings: items)
        }
    }
}

// MARK: - Supporting Types

/// Conflict alert info for duplicate shortcuts
private struct ConflictInfo {
    let newAction: HotKeyAction
    let existingAction: HotKeyAction
    let keyCode: UInt16
    let modifiers: HotKeyModifiers
}

/// Grouped bindings for section display
private struct BindingGroup {
    let category: HotKeyCategory
    let bindings: [HotKeyBinding]
}

// MARK: - Preview
#Preview {
    HotKeySettingsView()
        .frame(width: 700, height: 500)
}
