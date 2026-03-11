// SettingsArchivesPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

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

