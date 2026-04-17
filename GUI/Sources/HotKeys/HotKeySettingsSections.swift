// HotKeySettingsSections.swift
// MiMiNavigator
//
// Created by Codex on 17.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

struct ConflictInfo {
    let newAction: HotKeyAction
    let existingAction: HotKeyAction
    let keyCode: UInt16
    let modifiers: HotKeyModifiers
}

struct BindingGroup {
    let category: HotKeyCategory
    let bindings: [HotKeyBinding]
}

struct HotKeyTopToolbar: View {
    let store: HotKeyStore
    @Binding var filterText: String
    @Binding var showConflictsOnly: Bool

    var body: some View {
        HStack(spacing: 12) {
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

            HotKeyFilterField(text: $filterText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }
}

struct HotKeyFilterField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            TextField("Filter", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 120)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
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
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                )
        )
    }
}

struct HotKeyCategorySidebar: View {
    let store: HotKeyStore
    @Binding var selectedCategory: HotKeyCategory?
    let categoryColor: (HotKeyCategory?) -> Color

    var body: some View {
        VStack(spacing: 0) {
            categoryRow(
                label: "All",
                icon: "list.bullet",
                category: nil,
                count: store.allBindings.count
            )

            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            ForEach(HotKeyCategory.allCases) { category in
                categoryRow(
                    label: category.displayName,
                    icon: category.icon,
                    category: category,
                    count: store.bindings(for: category).count
                )
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }

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
}

struct HotKeyBindingsList: View {
    let groups: [BindingGroup]
    let hoveredAction: HotKeyAction?
    let categoryColor: (HotKeyCategory?) -> Color
    let isConflicting: (HotKeyBinding) -> Bool
    let isModified: (HotKeyBinding) -> Bool
    let onAssignShortcut: (HotKeyAction, UInt16, HotKeyModifiers) -> Void
    let onRemoveShortcut: (HotKeyAction) -> Void
    let onResetShortcut: (HotKeyAction) -> Void
    let onHoverAction: (HotKeyAction?) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if groups.isEmpty {
                    emptyStateView
                } else {
                    ForEach(groups, id: \.category) { group in
                        sectionHeader(group.category)
                        ForEach(group.bindings) { binding in
                            HotKeyBindingRow(
                                binding: binding,
                                isHovered: hoveredAction == binding.action,
                                hasConflict: isConflicting(binding),
                                isModified: isModified(binding),
                                onAssignShortcut: onAssignShortcut,
                                onRemoveShortcut: onRemoveShortcut,
                                onResetShortcut: onResetShortcut,
                                onHoverAction: onHoverAction
                            )
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 60)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No matching shortcuts")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ category: HotKeyCategory) -> some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.system(size: 10))
                .foregroundStyle(categoryColor(category))
            Text(category.displayName)
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}

struct HotKeyBindingRow: View {
    let binding: HotKeyBinding
    let isHovered: Bool
    let hasConflict: Bool
    let isModified: Bool
    let onAssignShortcut: (HotKeyAction, UInt16, HotKeyModifiers) -> Void
    let onRemoveShortcut: (HotKeyAction) -> Void
    let onResetShortcut: (HotKeyAction) -> Void
    let onHoverAction: (HotKeyAction?) -> Void

    private var hasBinding: Bool {
        binding.keyCode != 0
    }

    var body: some View {
        HStack(spacing: 10) {
            if hasConflict {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            Text(binding.action.displayName)
                .font(.system(size: 12))
                .foregroundStyle(hasConflict ? .red : .primary)
                .lineLimit(1)

            Spacer()

            HotKeyRecorderView(binding: binding) { keyCode, modifiers in
                onAssignShortcut(binding.action, keyCode, modifiers)
            }

            if hasBinding {
                Button {
                    onRemoveShortcut(binding.action)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove shortcut")
            } else {
                Color.clear.frame(width: 14)
            }

            if isHovered && isModified {
                Button {
                    onResetShortcut(binding.action)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { isHovered in
            onHoverAction(isHovered ? binding.action : nil)
        }
    }

    private var rowBackground: Color {
        if hasConflict { return Color.red.opacity(0.08) }
        if isHovered { return Color.accentColor.opacity(0.06) }
        return .clear
    }
}

struct HotKeyFooterBar: View {
    let store: HotKeyStore
    let onResetAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Button("Reset to Defaults", action: onResetAll)
                Divider()
                Button("Total Commander") { store.applyPreset(.totalCommander) }
                Button("Finder") { store.applyPreset(.finder) }
            } label: {
                Label("Reset All…", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.6, green: 0.0, blue: 0.0))
                Text("F5 is reserved by macOS")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color(red: 0.55, green: 0.0, blue: 0.0))
            }
            .help("macOS uses F5 for 'Move focus to toolbar'. To use F5, disable it in System Preferences → Keyboard → Shortcuts → Keyboard.")

            Spacer()

            Text("\(store.allBindings.count) shortcuts")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
