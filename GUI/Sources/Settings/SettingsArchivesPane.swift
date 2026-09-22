// SettingsArchivesPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI
import ExternalToolsKit

// MARK: - ════════════════════════════════════════════
// MARK:   Archives
// MARK: - ════════════════════════════════════════════

struct SettingsArchivesPane: View {

    @State private var prefs = UserPreferences.shared
    @State private var archivePassword: String = ArchivePasswordStore.shared.loadPassword() ?? ""
    @State private var showPassword: Bool = false
    @State private var registry = ExternalToolRegistry.shared
    @State private var doctor = ExternalToolDoctor.shared

    private let archiveTools: [ExternalTool] = [
        ExternalToolCatalog.sevenZip,
        ExternalToolCatalog.unar,
        ExternalToolCatalog.zip,
        ExternalToolCatalog.unzip,
        ExternalToolCatalog.tar,
        ExternalToolCatalog.ditto,
    ]

    private func prefBinding<T>(_ keyPath: WritableKeyPath<PreferencesSnapshot, T>) -> Binding<T> {
        Binding(
            get: { prefs.snapshot[keyPath: keyPath] },
            set: {
                prefs.snapshot[keyPath: keyPath] = $0
                AppStateProvider.shared?.applyPreferencesFromSnapshot()
            }
        )
    }

    // Supported formats from ArchiveModels.swift
    private let formatOptions: [(tag: String, label: String)] = [
        ("zip",     "ZIP Archive (.zip)"),
        ("tar.gz",  "TAR.GZ — gzip (.tar.gz)"),
        ("tar.bz2", "TAR.BZ2 — bzip2 (.tar.bz2)"),
        ("tar.xz",  "TAR.XZ — xz (.tar.xz)"),
        ("tar",     "TAR — uncompressed (.tar)"),
        ("7z",      "7-Zip Archive (.7z)"),
    ]

    private var sevenZipAvailable: Bool {
        registry.isAvailable("7z")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── 7z availability banner ────────────────────────
            if !sevenZipAvailable {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    Text("7-Zip is not installed — .7z format disabled.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    ExternalToolInfoButton(tool: ExternalToolCatalog.sevenZip)
                }
                .padding(10)
                .background(
                    SettingsVisualStyle.insetFill,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(SettingsVisualStyle.hairline, lineWidth: 0.5)
                }
            }

            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Archive Tools")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.bottom, 6)
                    Text("Installed archivers and extractors used by MiMiNavigator. Optional tools add RAR, 7z and legacy format support.")
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsVisualStyle.secondaryText)
                        .padding(.bottom, 8)
                    ForEach(archiveTools) { tool in
                        archiveToolRow(tool)
                        if tool.id != archiveTools.last?.id {
                            Divider().padding(.leading, 30)
                        }
                    }
                }
            }

            // ── Create ────────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Default format:", help: "Format used when creating a new archive") {
                        HStack(spacing: 6) {
                            Picker("", selection: prefBinding(\.archiveDefaultFormat)) {
                                ForEach(formatOptions, id: \.tag) { opt in
                                    Text(opt.label)
                                        .tag(opt.tag)
                                        .foregroundStyle(opt.tag == "7z" && !sevenZipAvailable ? .secondary : .primary)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 240)
                            .onChange(of: prefs.snapshot.archiveDefaultFormat) { _, newVal in
                                if newVal == "7z" && !sevenZipAvailable {
                                    prefs.snapshot.archiveDefaultFormat = "zip"
                                    prefs.save()
                                }
                            }
                        }
                    }
                    Divider()
                    SettingsRow(label: "Compression:", help: "Compression level: 1 = fastest, 9 = smallest file") {
                        HStack(spacing: 10) {
                            Text("Fast").font(.system(size: 11)).foregroundStyle(SettingsVisualStyle.secondaryText)
                            Slider(value: prefBinding(\.archiveCompressionLevel), in: 1...9, step: 1)
                                .frame(width: 120)
                            Text("Best").font(.system(size: 11)).foregroundStyle(SettingsVisualStyle.secondaryText)
                            Text("\(Int(prefs.snapshot.archiveCompressionLevel))").monospacedDigit()
                                .foregroundStyle(SettingsVisualStyle.secondaryText).frame(width: 18)
                        }
                    }
                }
            }

            // ── Extract ───────────────────────────────────────
            SettingsGroupBox {
                VStack(spacing: 0) {
                    SettingsRow(label: "Extract to:", help: "Where extracted files are placed") {
                        Toggle("Always extract into a subfolder", isOn: prefBinding(\.archiveExtractToSubfolder))
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Progress:", help: "Show extraction progress dialog for large archives") {
                        Toggle("Show extract progress dialog", isOn: prefBinding(\.archiveShowExtractProgress))
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
                            .buttonStyle(ThemedButtonStyle())
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
                        Picker("", selection: prefBinding(\.archiveOpenOnDoubleClick)) {
                            Text("Browse inside (navigate)").tag(true)
                            Text("Open with default app").tag(false)
                        }
                        .labelsHidden()
                        .frame(width: 230)
                    }
                    Divider()
                    SettingsRow(label: "Modified archive:", help: "Ask before repacking when leaving a modified archive") {
                        Toggle("Confirm repack on close", isOn: prefBinding(\.archiveConfirmOnModified))
                            .toggleStyle(.checkbox)
                    }
                    Divider()
                    SettingsRow(label: "Auto-repack:", help: "Silently repack modified archives without asking (overrides confirm)") {
                        Toggle("Auto-repack without asking", isOn: prefBinding(\.archiveAutoRepack))
                            .toggleStyle(.checkbox)
                            .disabled(!prefs.snapshot.archiveConfirmOnModified)
                    }
                }
            }
        }
        .onAppear { registry.refreshAll() }
    }

    // MARK: - Archive Tool Row
    private func archiveToolRow(_ tool: ExternalTool) -> some View {
        let available = registry.isAvailable(tool.id)
        return HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(available ? Color.green : Color.red)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(tool.name).font(.system(size: 12, weight: .medium))
                Text(tool.resolvedPath ?? tool.purpose)
                    .font(.system(size: 10, design: tool.resolvedPath == nil ? .default : .monospaced))
                    .foregroundStyle(SettingsVisualStyle.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(available ? "Installed" : "Missing")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(available ? Color.green : Color.red)
            if !available, tool.brewFormula != nil {
                Button("Install") {
                    Task {
                        let report = await doctor.diagnose(tool)
                        _ = await doctor.promptRepair(tool: tool, report: report, context: tool.purpose)
                        registry.refreshSingle(tool.id)
                    }
                }
                .buttonStyle(ThemedButtonStyle())
                .controlSize(.small)
                .disabled(doctor.isRepairing)
            }
            if !available {
                ExternalToolInfoButton(tool: tool)
            }
        }
        .padding(.vertical, 5)
    }
}
