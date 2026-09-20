// SettingsGeneralPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: General settings pane — language, editor, startup behavior

import SwiftUI

// MARK: - ════════════════════════════════════════════
// MARK:   General
// MARK: - ════════════════════════════════════════════

// MARK: - Supported App Languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case en     = "en"
    case de     = "de"
    case ru     = "ru"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .en:     return "English"
        case .de:     return "Deutsch"
        case .ru:     return "Русский"
        }
    }
    /// Apply language override to UserDefaults (takes effect on next launch)
    static func apply(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
        log.info("[Settings] Language set to '\(language.displayName)' — restart required")
    }
    /// Read current setting from UserDefaults
    static func current() -> AppLanguage {
        guard let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
              let first = langs.first,
              let lang = AppLanguage(rawValue: first) else {
            return .system
        }
        return lang
    }
}
// MARK: - SettingsGeneralPane
struct SettingsGeneralPane: View {

    @State private var prefs = UserPreferences.shared
    @State private var selectedLanguage: AppLanguage = AppLanguage.current()
    @State private var showRestartHint: Bool = false
    @State private var scaleStore = InterfaceScaleStore.shared

    /// Convenience binding that auto-saves on every change.
    private func prefBinding<T>(_ keyPath: WritableKeyPath<PreferencesSnapshot, T>) -> Binding<T> {
        Binding(
            get: { prefs.snapshot[keyPath: keyPath] },
            set: {
                prefs.snapshot[keyPath: keyPath] = $0
                AppStateProvider.shared?.applyPreferencesFromSnapshot()
            }
        )
    }

    private var showHiddenFilesBinding: Binding<Bool> {
        Binding(
            get: { prefs.snapshot.showHiddenFiles },
            set: { AppStateProvider.shared?.setShowHiddenFiles($0) }
        )
    }

    private func optionalBoolBinding(_ keyPath: WritableKeyPath<PreferencesSnapshot, Bool?>) -> Binding<Bool> {
        Binding(
            get: { prefs.snapshot[keyPath: keyPath] ?? true },
            set: { prefs.snapshot[keyPath: keyPath] = $0 }
        )
    }

    private func optionalDoubleBinding(_ keyPath: WritableKeyPath<PreferencesSnapshot, Double?>, default defaultValue: Double) -> Binding<Double> {
        Binding(
            get: { prefs.snapshot[keyPath: keyPath] ?? defaultValue },
            set: { prefs.snapshot[keyPath: keyPath] = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Appearance ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Appearance:", help: "Override system light/dark mode") {
                        Picker("", selection: prefBinding(\.appearance)) {
                            Text("Follow System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 260)
                    }
                    Divider()
                    SettingsRow(label: "Toolbar graphs:", help: "Choose which live application resource graphs appear beside TEST BUILD") {
                        HStack(spacing: 16) {
                            Toggle("Memory", isOn: optionalBoolBinding(\.toolbarShowMemoryGraph))
                                .toggleStyle(.checkbox)
                            Toggle("Threads", isOn: optionalBoolBinding(\.toolbarShowThreadsGraph))
                                .toggleStyle(.checkbox)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Graph intervals:", help: "Set independent refresh intervals for memory and thread measurements") {
                        HStack(spacing: 14) {
                            intervalPicker("Memory", selection: optionalDoubleBinding(\.toolbarMemoryGraphInterval, default: 5))
                            intervalPicker("Threads", selection: optionalDoubleBinding(\.toolbarThreadsGraphInterval, default: 10))
                        }
                    }
                }
            }

            // ── Language ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Language:", help: "UI language for menus, labels and dialogs") {
                        HStack(spacing: 12) {
                            Picker("", selection: $selectedLanguage) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                            .onChange(of: selectedLanguage) { _, newLang in
                                AppLanguage.apply(newLang)
                                showRestartHint = newLang != .system
                            }
                            if showRestartHint {
                                Label("Restart app to apply", systemImage: "arrow.clockwise")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }

            // ── Interface Scale ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Interface scale:", help: "Scale all UI elements — fonts, icons, row heights") {
                        HStack(spacing: 12) {
                            Image(systemName: "eye")
                                .font(.system(size: 14))
                                .foregroundStyle(SettingsVisualStyle.secondaryText)
                            Text("Default interface scale")
                                .font(.system(size: 14))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { scaleStore.scaleFactor != InterfaceScaleStore.defaultScale },
                                set: { enabled in
                                    if !enabled { scaleStore.resetToDefault() }
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }
                    }
                    Divider()
                    SettingsRow(label: "", help: "Drag to adjust UI scale from 80% to 200%") {
                        HStack(spacing: 10) {
                            Slider(
                                value: Binding(
                                    get: { scaleStore.scaleFactor },
                                    set: { scaleStore.scaleFactor = $0 }
                                ),
                                in: InterfaceScaleStore.minScale...InterfaceScaleStore.maxScale,
                                step: InterfaceScaleStore.step
                            )
                            .frame(width: 200)
                            Text("\(scaleStore.percentDisplay)%")
                                .monospacedDigit()
                                .foregroundStyle(scaleStore.scaleFactor != InterfaceScaleStore.defaultScale ? Color.accentColor : .secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }

            // ── Text & Icons ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Panel font size:", help: "Font size used in file lists") {
                        HStack(spacing: 10) {
                            Slider(value: prefBinding(\.panelFontSize), in: 10...18, step: 1)
                                .frame(width: 140)
                            Text("\(Int(prefs.snapshot.panelFontSize)) pt")
                                .monospacedDigit()
                                .foregroundStyle(SettingsVisualStyle.secondaryText)
                                .frame(width: 36)
                        }
                    }

                    Divider().padding(.leading, 0)

                    SettingsRow(label: "Icon size:", help: "Size of file/folder icons in panels") {
                        Picker("", selection: prefBinding(\.iconSize)) {
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                }
            }

            // ── Files ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Hidden files:", help: "Show files and folders starting with dot (.)") {
                        Toggle("Show hidden files (.dotfiles)", isOn: showHiddenFilesBinding)
                            .toggleStyle(.checkbox)
                    }

                    Divider()

                    SettingsRow(label: "Extensions:", help: "Always show file extensions in file names") {
                        Toggle("Always show file extensions", isOn: prefBinding(\.showExtensions))
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Columns ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(
                        label: "Auto-fit cols:",
                        help: "Shrink data columns to fit their content when navigating. Empty columns collapse to minimum width. Recovered space goes to the Name column."
                    ) {
                        Toggle("Auto-fit cols", isOn: prefBinding(\.autoFitColumnsOnNavigate))
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Startup ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Start in:", help: "Which directory to open at app launch") {
                        Picker("", selection: prefBinding(\.startupPath)) {
                            Text("Home folder (~)").tag("home")
                            Text("Last visited location").tag("last")
                            Text("Desktop").tag("desktop")
                            Text("Downloads").tag("downloads")
                        }
                        .frame(maxWidth: 220)
                        .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Resource Graph Interval Picker
    private func intervalPicker(_ title: String, selection: Binding<Double>) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(SettingsVisualStyle.secondaryText)
            Picker("", selection: selection) {
                ForEach([3.0, 5.0, 10.0, 15.0, 30.0, 60.0], id: \.self) { seconds in
                    Text("\(Int(seconds)) s").tag(seconds)
                }
            }
            .labelsHidden()
            .frame(width: 72)
        }
    }
}
