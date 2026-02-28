// SettingsPanes.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: All settings panes — General (real), rest are stubs for next iterations.

import SwiftUI

// MARK: - Shared style helpers

private struct SettingsRow<Content: View>: View {
    let label: String
    let help: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 200, alignment: .trailing)
                .help(help)
            Spacer().frame(width: 16)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

private struct SettingsGroupBox<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DialogColors.light)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DialogColors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}

private struct StubPane: View {
    let section: SettingsSection

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: section.icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("\(section.rawValue) settings coming soon")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

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

    @AppStorage("settings.appearance")       private var appearance: String = "system"
    @AppStorage("settings.panelFontSize")    private var panelFontSize: Double = 13
    @AppStorage("settings.iconSize")         private var iconSize: String = "medium"
    @AppStorage("settings.showHiddenFiles")  private var showHiddenFiles: Bool = false
    @AppStorage("settings.showExtensions")   private var showExtensions: Bool = true
    @AppStorage("settings.startupPath")      private var startupPath: String = "home"
    @State private var selectedLanguage: AppLanguage = AppLanguage.current()
    @State private var showRestartHint: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Appearance ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Appearance:", help: "Override system light/dark mode") {
                        Picker("", selection: $appearance) {
                            Text("Follow System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 260)
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

            // ── Text & Icons ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Panel font size:", help: "Font size used in file lists") {
                        HStack(spacing: 10) {
                            Slider(value: $panelFontSize, in: 10...18, step: 1)
                                .frame(width: 140)
                            Text("\(Int(panelFontSize)) pt")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 36)
                        }
                    }

                    Divider().padding(.leading, 0)

                    SettingsRow(label: "Icon size:", help: "Size of file/folder icons in panels") {
                        Picker("", selection: $iconSize) {
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
                        Toggle("Show hidden files (.dotfiles)", isOn: $showHiddenFiles)
                            .toggleStyle(.checkbox)
                    }

                    Divider()

                    SettingsRow(label: "Extensions:", help: "Always show file extensions in file names") {
                        Toggle("Always show file extensions", isOn: $showExtensions)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Startup ──
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Start in:", help: "Which directory to open at app launch") {
                        Picker("", selection: $startupPath) {
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
}

// MARK: - ════════════════════════════════════════════
// MARK:   Panels
// MARK: - ════════════════════════════════════════════

struct SettingsPanelsPane: View {

    // Sync these keys with UserPreferences / AppState where wired
    @AppStorage("settings.panels.showHiddenFiles")   private var showHiddenFiles: Bool = false
    @AppStorage("settings.panels.showExtensions")    private var showExtensions: Bool = true
    @AppStorage("settings.panels.showIcons")         private var showIcons: Bool = true
    @AppStorage("settings.panels.calculateSizes")    private var calculateSizes: Bool = false
    @AppStorage("settings.panels.highlightBorder")   private var highlightBorder: Bool = true
    @AppStorage("settings.panels.defaultSort")       private var defaultSort: String = "name"
    @AppStorage("settings.panels.sortAscending")     private var sortAscending: Bool = true
    @AppStorage("settings.panels.dateFormat")        private var dateFormat: String = "short"
    @AppStorage("settings.panels.showSizeInKB")      private var showSizeInKB: Bool = false
    @AppStorage("settings.panels.openOnSingleClick") private var openOnSingleClick: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Files display ───────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Hidden files:", help: "Show files and folders starting with dot (.)") {
                        Toggle("Show hidden files (.dotfiles)", isOn: $showHiddenFiles)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Extensions:", help: "Always show file extensions") {
                        Toggle("Always show file extensions", isOn: $showExtensions)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Icons:", help: "Show file and folder icons in list view") {
                        Toggle("Show icons in file list", isOn: $showIcons)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Folder sizes:", help: "Calculate and show folder sizes (slower, uses du)") {
                        Toggle("Calculate folder sizes", isOn: $calculateSizes)
                            .toggleStyle(.checkbox)
                        if calculateSizes {
                            Text("May slow down large directories")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                                .padding(.leading, 8)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Active panel:", help: "Highlight border of the focused panel") {
                        Toggle("Highlight active panel border", isOn: $highlightBorder)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Sorting ──────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Default sort:", help: "Sort files by this column when opening a folder") {
                        HStack(spacing: 12) {
                            Picker("", selection: $defaultSort) {
                                Text("Name").tag("name")
                                Text("Date").tag("date")
                                Text("Size").tag("size")
                                Text("Type").tag("type")
                            }
                            .labelsHidden()
                            .frame(width: 110)
                            Picker("", selection: $sortAscending) {
                                Text("↑ Ascending").tag(true)
                                Text("↓ Descending").tag(false)
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                    }
                }
            }

            // ── Date & Size format ───────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Date format:", help: "How modification date is shown in the file list") {
                        Picker("", selection: $dateFormat) {
                            Text("Short  (14.02.26)").tag("short")
                            Text("Medium (Feb 14, 2026)").tag("medium")
                            Text("Relative (2 days ago)").tag("relative")
                            Text("ISO-8601").tag("iso")
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    Divider()
                    SettingsRow(label: "Size display:", help: "Show file sizes in KB instead of auto-scaling") {
                        Toggle("Always show size in KB", isOn: $showSizeInKB)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Navigation ───────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Open on:", help: "Open files and folders with single or double click") {
                        Picker("", selection: $openOnSingleClick) {
                            Text("Double click").tag(false)
                            Text("Single click").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                }
            }
        }
    }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Tabs
// MARK: - ════════════════════════════════════════════

struct SettingsTabsPane: View {

    @AppStorage("settings.tabs.restoreOnLaunch")    private var restoreOnLaunch: Bool = true
    @AppStorage("settings.tabs.openFolderInNewTab") private var openFolderInNewTab: Bool = false
    @AppStorage("settings.tabs.closeLastKeepsPanel")private var closeLastKeepsPanel: Bool = true
    @AppStorage("settings.tabs.position")           private var position: String = "top"
    @AppStorage("settings.tabs.showCloseButton")    private var showCloseButton: Bool = true
    @AppStorage("settings.tabs.maxTabs")            private var maxTabs: Double = 32
    @AppStorage("settings.tabs.sortByName")         private var sortByName: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Behaviour ────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Restore tabs:", help: "Reopen tabs from last session on app launch") {
                        Toggle("Restore tabs on launch", isOn: $restoreOnLaunch)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "New tab on Enter:", help: "Open folder in a new tab instead of navigating in-place") {
                        Toggle("Open folders in new tab (double-click)", isOn: $openFolderInNewTab)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Close last tab:", help: "Keep panel visible when closing the last remaining tab") {
                        Picker("", selection: $closeLastKeepsPanel) {
                            Text("Keep panel open (home dir)").tag(true)
                            Text("Close panel").tag(false)
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }
            }

            // ── Appearance ───────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Tab bar position:", help: "Where the tab bar is shown relative to the file list") {
                        Picker("", selection: $position) {
                            Text("Top").tag("top")
                            Text("Bottom").tag("bottom")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 160)
                    }
                    Divider()
                    SettingsRow(label: "Close button:", help: "Show × button on each tab") {
                        Toggle("Show close button on tabs", isOn: $showCloseButton)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Limits ───────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Max open tabs:", help: "Maximum number of tabs per panel (2–64)") {
                        HStack(spacing: 10) {
                            Slider(value: $maxTabs, in: 2...64, step: 1)
                                .frame(width: 140)
                            Text("\(Int(maxTabs))").monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Archives
// MARK: - ════════════════════════════════════════════

struct SettingsArchivesPane: View {

    @AppStorage("settings.archives.defaultCreateFormat") private var defaultCreateFormat: String = "zip"
    @State private var archivePassword: String = ArchivePasswordStore.shared.loadPassword() ?? ""
    @State private var showPassword: Bool = false
    @AppStorage("settings.archives.openOnDoubleClick")   private var openOnDoubleClick: Bool = true
    @AppStorage("settings.archives.confirmOnModified")   private var confirmOnModified: Bool = true
    @AppStorage("settings.archives.autoRepack")          private var autoRepack: Bool = true
    @AppStorage("settings.archives.compressionLevel")    private var compressionLevel: Double = 6
    @AppStorage("settings.archives.showExtractProgress") private var showExtractProgress: Bool = true
    @AppStorage("settings.archives.extractToSubfolder")  private var extractToSubfolder: Bool = true

    // Supported formats from ArchiveModels.swift
    private let formatOptions: [(tag: String, label: String)] = [
        ("zip",     "ZIP Archive (.zip)"),
        ("tar.gz",  "TAR.GZ — gzip (.tar.gz)"),
        ("tar.bz2", "TAR.BZ2 — bzip2 (.tar.bz2)"),
        ("tar.xz",  "TAR.XZ — xz (.tar.xz)"),
        ("tar",     "TAR — uncompressed (.tar)"),
        ("7z",      "7-Zip Archive (.7z)"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Create ────────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Default format:", help: "Format used when creating a new archive") {
                        Picker("", selection: $defaultCreateFormat) {
                            ForEach(formatOptions, id: \.tag) { opt in
                                Text(opt.label).tag(opt.tag)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 240)
                    }
                    Divider()
                    SettingsRow(label: "Compression:", help: "Compression level: 1 = fastest, 9 = smallest file") {
                        HStack(spacing: 10) {
                            Text("Fast").font(.system(size: 11)).foregroundStyle(.secondary)
                            Slider(value: $compressionLevel, in: 1...9, step: 1)
                                .frame(width: 120)
                            Text("Best").font(.system(size: 11)).foregroundStyle(.secondary)
                            Text("\(Int(compressionLevel))").monospacedDigit()
                                .foregroundStyle(.secondary).frame(width: 18)
                        }
                    }
                }
            }

            // ── Extract ───────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Extract to:", help: "Where extracted files are placed") {
                        Toggle("Always extract into a subfolder", isOn: $extractToSubfolder)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Progress:", help: "Show extraction progress dialog for large archives") {
                        Toggle("Show extract progress dialog", isOn: $showExtractProgress)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // ── Password ──────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Archive password:", help: "Default password for encrypted archives (ZIP, 7z, RAR). Stored in macOS Keychain.") {
                        HStack(spacing: 8) {
                            if showPassword {
                                TextField("Enter password…", text: $archivePassword)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
                            } else {
                                SecureField("Enter password…", text: $archivePassword)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .help(showPassword ? "Hide password" : "Show password")

                            Button("Save") {
                                ArchivePasswordStore.shared.savePassword(archivePassword)
                            }
                            .controlSize(.small)
                            .disabled(archivePassword.isEmpty)

                            if !archivePassword.isEmpty {
                                Button {
                                    archivePassword = ""
                                    ArchivePasswordStore.shared.deletePassword()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Remove saved password")
                            }
                        }
                    }
                    Text("Used automatically when opening password-protected archives. If wrong, you'll be prompted.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 216)
                        .padding(.top, 2)
                }
            }

            // ── Browse ────────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Open archive:", help: "How to handle double-click on an archive file") {
                        Picker("", selection: $openOnDoubleClick) {
                            Text("Browse inside (navigate)").tag(true)
                            Text("Open with default app").tag(false)
                        }
                        .labelsHidden()
                        .frame(width: 230)
                    }
                    Divider()
                    SettingsRow(label: "Modified archive:", help: "Ask before repacking when leaving a modified archive") {
                        Toggle("Confirm repack on close", isOn: $confirmOnModified)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Auto-repack:", help: "Silently repack modified archives without asking (overrides confirm)") {
                        Toggle("Auto-repack without asking", isOn: $autoRepack)
                            .toggleStyle(.checkbox)
                            .disabled(confirmOnModified == false)
                    }
                }
            }
        }
    }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Network  (stub — Network pane in ConnectToServer)
// MARK: - ════════════════════════════════════════════

struct SettingsNetworkPane: View {
    @AppStorage("settings.network.timeoutSec")       private var timeoutSec: Double = 15
    @AppStorage("settings.network.retryCount")       private var retryCount: Double = 3
    @AppStorage("settings.network.savePasswords")    private var savePasswords: Bool = true
    @AppStorage("settings.network.showInSidebar")    private var showInSidebar: Bool = true
    @AppStorage("settings.network.autoReconnect")    private var autoReconnect: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Timeout:", help: "Connection timeout in seconds") {
                        HStack(spacing: 10) {
                            Slider(value: $timeoutSec, in: 5...60, step: 5)
                                .frame(width: 140)
                            Text("\(Int(timeoutSec)) s")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 36)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Retry attempts:", help: "How many times to retry on connection drop") {
                        HStack(spacing: 10) {
                            Slider(value: $retryCount, in: 0...10, step: 1)
                                .frame(width: 140)
                            Text("\(Int(retryCount))×")
                                .monospacedDigit().foregroundStyle(.secondary).frame(width: 28)
                        }
                    }
                    Divider()
                    SettingsRow(label: "Auto-reconnect:", help: "Try to restore dropped connections automatically") {
                        Toggle("Reconnect automatically", isOn: $autoReconnect)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Passwords:", help: "Save server passwords in macOS Keychain") {
                        Toggle("Save passwords in Keychain", isOn: $savePasswords)
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Sidebar:", help: "Show connected servers in the Favorites sidebar") {
                        Toggle("Show connected servers in sidebar", isOn: $showInSidebar)
                            .toggleStyle(.checkbox)
                    }
                }
            }

            // Info row
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                Text("Detailed server configuration is available in Connect to Server (⌘K)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Diff Tool
// MARK: - ════════════════════════════════════════════

struct SettingsDiffToolPane: View {

    @State private var registry    = DiffToolRegistry.shared
    @State private var selectedID: String? = nil
    @State private var showAddSheet  = false
    @State private var editingTool: DiffTool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Active tool picker ───────────────────────────
            SettingsGroupBox {
                SettingsRow(label: "Active tool:",
                            help: "Tool launched by Compare button. 'Auto' picks best installed.") {
                    Picker("", selection: Binding(
                        get: { registry.activeToolID },
                        set: { registry.activeToolID = $0 }
                    )) {
                        Text("Auto (best available)").tag("auto")
                        Divider()
                        ForEach(registry.tools.filter { $0.isEnabled }) { tool in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(tool.isInstalled ? Color.green : Color.secondary.opacity(0.4))
                                    .frame(width: 7, height: 7)
                                Text(tool.name)
                                    .foregroundStyle(tool.isInstalled ? .primary : .secondary)
                            }
                            .tag(tool.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
            }

            // ── Tools list ────────────────────────────────────
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 8) {

                    Text("AVAILABLE TOOLS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(0.5)

                    VStack(spacing: 0) {
                        ForEach(registry.tools) { tool in
                            toolRow(tool)
                            if tool.id != registry.tools.last?.id {
                                Divider().padding(.leading, 32)
                            }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                    )

                    // +/- / up/down / Edit toolbar
                    HStack(spacing: 1) {
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus").frame(width: 26, height: 20)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .help("Add custom diff tool")

                        Button {
                            if let id = selectedID { registry.remove(id: id); selectedID = nil }
                        } label: {
                            Image(systemName: "minus").frame(width: 26, height: 20)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .disabled(cannotRemove)
                        .help("Remove — only custom tools can be deleted")

                        Divider().frame(height: 16).padding(.horizontal, 6)

                        Button { if let id = selectedID { registry.moveUp(id: id) } } label: {
                            Image(systemName: "chevron.up").frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .disabled(selectedID == nil || registry.tools.first?.id == selectedID)
                        .help("Higher priority")

                        Button { if let id = selectedID { registry.moveDown(id: id) } } label: {
                            Image(systemName: "chevron.down").frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .disabled(selectedID == nil || registry.tools.last?.id == selectedID)
                        .help("Lower priority")

                        Spacer()

                        if let id = selectedID,
                           let tool = registry.tools.first(where: { $0.id == id }) {
                            Button("Edit…") { editingTool = tool }
                                .controlSize(.small).buttonStyle(.bordered)
                        }
                    }
                }
            }

            // ── No tools warning ─────────────────────────────
            if registry.tools.filter({ $0.isEnabled && $0.isInstalled }).isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text("No diff tool installed. Download DiffMerge (free) or Beyond Compare.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("DiffMerge↗") {
                        NSWorkspace.shared.open(URL(string: "https://sourcegear.com/diffmerge/")!)
                    }.controlSize(.small)
                    Button("Beyond Compare↗") {
                        NSWorkspace.shared.open(URL(string: "https://www.scootersoftware.com/")!)
                    }.controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            DiffToolEditSheet(tool: nil) { registry.add($0) }
        }
        .sheet(item: $editingTool) { tool in
            DiffToolEditSheet(tool: tool) { registry.update($0) }
        }
    }

    // MARK: - Row

    private func toolRow(_ tool: DiffTool) -> some View {
        let isSel = selectedID == tool.id
        return HStack(spacing: 10) {
            Circle()
                .fill(dotColor(tool, isSel))
                .frame(width: 8, height: 8)
                .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tool.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSel ? .white : (tool.isEnabled ? .primary : .secondary))

                    badge(tool.scope.label,
                          fg: isSel ? .white.opacity(0.7) : .secondary,
                          bg: isSel ? .white.opacity(0.2) : Color(nsColor: .separatorColor).opacity(0.6))

                    if tool.id == registry.activeToolID {
                        badge("ACTIVE",
                              fg: isSel ? .white.opacity(0.9) : .accentColor,
                              bg: isSel ? .white.opacity(0.2) : .accentColor.opacity(0.12))
                    }
                    if !tool.isInstalled {
                        badge("not found",
                              fg: isSel ? .white.opacity(0.6) : .orange,
                              bg: isSel ? .white.opacity(0.15) : .orange.opacity(0.10))
                    }
                }
                Text(tool.appPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSel ? .white.opacity(0.6) : .secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { tool.isEnabled },
                set: { _ in registry.toggleEnabled(id: tool.id) }
            ))
            .labelsHidden().toggleStyle(.checkbox)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 7)
        .background(isSel ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedID = tool.id }
    }

    // MARK: - Helpers

    private var cannotRemove: Bool {
        guard let id = selectedID,
              let t  = registry.tools.first(where: { $0.id == id }) else { return true }
        return t.isBuiltIn
    }

    private func dotColor(_ t: DiffTool, _ sel: Bool) -> Color {
        if sel            { return .white }
        if !t.isInstalled { return Color(nsColor: .quaternaryLabelColor) }
        return t.isEnabled ? .green : .orange
    }

    private func badge(_ text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(bg.cornerRadius(4))
    }
}

// MARK: - Add / Edit Sheet

struct DiffToolEditSheet: View {

    let tool:   DiffTool?
    let onSave: (DiffTool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name:      String
    @State private var appPath:   String
    @State private var arguments: String
    @State private var scope:     DiffToolScope

    init(tool: DiffTool?, onSave: @escaping (DiffTool) -> Void) {
        self.tool = tool; self.onSave = onSave
        _name      = State(initialValue: tool?.name      ?? "")
        _appPath   = State(initialValue: tool?.appPath   ?? "")
        _arguments = State(initialValue: tool?.arguments ?? #""%left" "%right""#)
        _scope     = State(initialValue: tool?.scope     ?? .both)
    }

    private var pathExists: Bool { FileManager.default.fileExists(atPath: appPath) }
    private var isValid: Bool    { !name.isEmpty && !appPath.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            Text(tool == nil ? "Add Diff Tool" : "Edit Diff Tool")
                .font(.system(size: 15, weight: .semibold))

            labeledField("Name:", placeholder: "e.g. Beyond Compare", text: $name)

            VStack(alignment: .leading, spacing: 4) {
                Text("Application or binary:").font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("/Applications/MyTool.app", text: $appPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Button("Browse…") { browse() }.controlSize(.small)
                }
                if !appPath.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: pathExists ? "checkmark.circle.fill" : "xmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(pathExists ? Color.green : Color.orange)
                        Text(pathExists ? "Found on disk" : "Not found at this path")
                            .font(.system(size: 11))
                            .foregroundStyle(pathExists ? Color.secondary : Color.orange)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Arguments  (use %left and %right):")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                TextField(#""%left" "%right""#, text: $arguments)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Text(#"Example: --nosplash "%left" "%right""#)
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Supports:").font(.system(size: 12)).foregroundStyle(.secondary)
                Picker("", selection: $scope) {
                    ForEach(DiffToolScope.allCases) { s in Text(s.label).tag(s) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Button(tool == nil ? "Add" : "Save") {
                    onSave(DiffTool(
                        id:        tool?.id ?? UUID().uuidString,
                        name:      name,
                        appPath:   appPath,
                        arguments: arguments,
                        scope:     scope,
                        isBuiltIn: tool?.isBuiltIn ?? false,
                        isEnabled: tool?.isEnabled ?? true
                    ))
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [.unixExecutable, .application]
        panel.message = "Choose a diff tool executable or .app bundle"
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appPath = url.path
        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
    }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Hotkeys  — uses existing HotKeySettingsView
// MARK: - ════════════════════════════════════════════

struct SettingsHotkeysPane: View {
    var body: some View {
        HotKeySettingsView(embedded: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// NOTE: SettingsColorsPane → SettingsColorsPane.swift
// NOTE: SettingsPermissionsPane → SettingsPermissionsPane.swift
