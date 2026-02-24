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
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
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

struct SettingsGeneralPane: View {

    @AppStorage("settings.appearance")       private var appearance: String = "system"
    @AppStorage("settings.panelFontSize")    private var panelFontSize: Double = 13
    @AppStorage("settings.iconSize")         private var iconSize: String = "medium"
    @AppStorage("settings.showHiddenFiles")  private var showHiddenFiles: Bool = false
    @AppStorage("settings.showExtensions")   private var showExtensions: Bool = true
    @AppStorage("settings.startupPath")      private var startupPath: String = "home"

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

    @AppStorage("settings.diff.preferredTool") private var preferredTool: String = "auto"
    @AppStorage("settings.diff.customPath")    private var customPath: String = ""
    @AppStorage("settings.diff.customArgs")    private var customArgs: String = ""%left" "%right""

    // Detection cache — recomputed on appear
    @State private var diffMergeFound: Bool = false
    @State private var fileMergeFound: Bool = false
    @State private var kaleidoscopeFound: Bool = false
    @State private var bbEditFound: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Tool selection ────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Diff tool:", help: "Which application to use when comparing files or folders") {
                        Picker("", selection: $preferredTool) {
                            Text("Auto-detect (recommended)").tag("auto")
                            Divider()
                            diffToolOption("DiffMerge",     found: diffMergeFound,    tag: "diffmerge")
                            diffToolOption("FileMerge",     found: fileMergeFound,     tag: "filemerge")
                            diffToolOption("Kaleidoscope",  found: kaleidoscopeFound,  tag: "kaleidoscope")
                            diffToolOption("BBEdit",        found: bbEditFound,        tag: "bbedit")
                            Divider()
                            Text("Custom…").tag("custom")
                        }
                        .labelsHidden()
                        .frame(width: 240)
                    }
                }
            }

            // ── Status badges ─────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 6) {
                    toolStatusRow("DiffMerge",    icon: "arrow.left.arrow.right.square",
                                  found: diffMergeFound,   path: diffMergePath())
                    Divider()
                    toolStatusRow("FileMerge",    icon: "doc.on.doc",
                                  found: fileMergeFound,    path: "/usr/bin/opendiff")
                    Divider()
                    toolStatusRow("Kaleidoscope", icon: "sparkles.square.filled.on.square",
                                  found: kaleidoscopeFound, path: "/Applications/Kaleidoscope 3.app")
                    Divider()
                    toolStatusRow("BBEdit",       icon: "chevron.left.forwardslash.chevron.right",
                                  found: bbEditFound,       path: "/Applications/BBEdit.app")
                }
            }

            // ── Custom tool ───────────────────────────────────
            if preferredTool == "custom" {
                SettingsGroupBox {
                    VStack(spacing: 0) {
                        SettingsRow(label: "Executable:", help: "Path to the diff tool binary or .app") {
                            HStack(spacing: 8) {
                                TextField("e.g. /usr/local/bin/meld", text: $customPath)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                                Button("Browse…") { pickCustomPath() }
                                    .controlSize(.small)
                            }
                        }
                        Divider()
                        SettingsRow(label: "Arguments:", help: "Use %left and %right as placeholders") {
                            TextField("\"%left\" \"%right\"", text: $customArgs)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                }
            }

            // ── Install hint ─────────────────────────────────
            if !diffMergeFound && !fileMergeFound {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.system(size: 11))
                    Text("No diff tool detected. Install DiffMerge (free) or Xcode (includes FileMerge).")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Get DiffMerge…") {
                        NSWorkspace.shared.open(URL(string: "https://sourcegear.com/diffmerge/")!)
                    }
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .onAppear { detectInstalledTools() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func diffToolOption(_ name: String, found: Bool, tag: String) -> some View {
        HStack {
            Text(name)
            if found {
                Text("✓").foregroundStyle(.green).font(.system(size: 10))
            } else {
                Text("not installed").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .tag(tag)
    }

    private func toolStatusRow(_ name: String, icon: String, found: Bool, path: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(found ? Color.accentColor : Color.secondary)
                .frame(width: 20)
            Text(name).font(.system(size: 13, weight: .medium))
            Spacer()
            if found {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Text("Not found")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 5)
    }

    private func diffMergePath() -> String {
        ["/Applications/DiffMerge.app",
         "\(NSHomeDirectory())/Applications/DiffMerge.app"]
            .first { FileManager.default.fileExists(atPath: $0) } ?? "/Applications/DiffMerge.app"
    }

    private func detectInstalledTools() {
        let fm = FileManager.default
        diffMergeFound    = fm.fileExists(atPath: "/Applications/DiffMerge.app")
                         || fm.fileExists(atPath: "\(NSHomeDirectory())/Applications/DiffMerge.app")
        fileMergeFound    = fm.fileExists(atPath: "/usr/bin/opendiff")
        kaleidoscopeFound = fm.fileExists(atPath: "/Applications/Kaleidoscope 3.app")
                         || fm.fileExists(atPath: "/Applications/Kaleidoscope.app")
        bbEditFound       = fm.fileExists(atPath: "/Applications/BBEdit.app")
    }

    private func pickCustomPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.unixExecutable, .application]
        panel.message = "Choose a diff tool executable or .app"
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        customPath = url.path
    }
}

// MARK: - ════════════════════════════════════════════
// MARK:   Hotkeys  — uses existing HotKeySettingsView
// MARK: - ════════════════════════════════════════════

struct SettingsHotkeysPane: View {
    var body: some View {
        HotKeySettingsView()
            .frame(minHeight: 380)
    }
}

// NOTE: SettingsColorsPane → SettingsColorsPane.swift
// NOTE: SettingsPermissionsPane → SettingsPermissionsPane.swift
