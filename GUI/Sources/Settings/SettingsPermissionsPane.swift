// SettingsPermissionsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Permissions settings — sandbox folder access (like QSpace) + system permissions.
//   Uses NSOpenPanel + security-scoped bookmarks via BookmarkStore.
//   Shows Full Disk Access status with deep-link to System Settings.

import AppKit
import SwiftUI

// MARK: - SettingsPermissionsPane

struct SettingsPermissionsPane: View {

    @State private var authorizedFolders: [AuthorizedFolder] = []
    @State private var hasFullDiskAccess: Bool = false
    @State private var isCheckingAccess: Bool = true
    @State private var hoveredFolderID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Authorized Folders ─────────────────────────────
            paneGroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Folder Access")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Due to macOS sandbox restrictions, MiMiNavigator needs your permission to access folders outside of standard locations. Add folders below to grant access.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Folder list
                    VStack(spacing: 0) {
                        if authorizedFolders.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Image(systemName: "folder.badge.questionmark")
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundStyle(.tertiary)
                                    Text("No authorized folders")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else {
                            ForEach(authorizedFolders) { folder in
                                folderRow(folder)
                                if folder.id != authorizedFolders.last?.id {
                                    Divider().padding(.leading, 32)
                                }
                            }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
                    )

                    // +/- buttons (QSpace style)
                    HStack(spacing: 0) {
                        Button {
                            addFolder()
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 28, height: 22)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Add folder permission")

                        Divider().frame(height: 18).padding(.horizontal, 1)

                        Button {
                            removeSelectedFolder()
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 28, height: 22)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(authorizedFolders.isEmpty)
                        .help("Remove selected folder permission")
                    }
                }
            }

            // ── Full Disk Access ───────────────────────────────
            paneGroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        // Status badge
                        if isCheckingAccess {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 22, height: 22)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(hasFullDiskAccess
                                          ? Color.green.opacity(0.15)
                                          : Color.orange.opacity(0.15))
                                    .frame(width: 22, height: 22)
                                Image(systemName: hasFullDiskAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(hasFullDiskAccess ? Color.green : Color.orange)
                            }
                        }

                        Button {
                            openFullDiskAccessSettings()
                        } label: {
                            Text("Full Disk Access Permission")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(hasFullDiskAccess ? .green : .orange)

                        Spacer()

                        Button {
                            checkFullDiskAccess()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Re-check Full Disk Access status")
                    }

                    Text("For full access to Desktop, Documents, Downloads, Removable Volumes, iCloud Drive, and other protected locations, add MiMiNavigator to Full Disk Access in System Settings → Privacy & Security.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !hasFullDiskAccess && !isCheckingAccess {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.orange)
                                .font(.system(size: 11))
                            Text("Without Full Disk Access some folders may be inaccessible. Click the button above to open System Settings.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }

            // ── Other Permissions ──────────────────────────────
            paneGroupBox {
                VStack(spacing: 0) {
                    permissionRow(
                        icon: "network",
                        title: "Network Access",
                        description: "Required for FTP, SFTP, SMB connections",
                        status: .granted
                    )
                    Divider().padding(.leading, 40)
                    permissionRow(
                        icon: "desktopcomputer",
                        title: "Automation (Finder)",
                        description: "Used for some file operations and diff tool launch",
                        status: .unknown
                    )
                    Divider().padding(.leading, 40)
                    permissionRow(
                        icon: "key",
                        title: "Keychain Access",
                        description: "Stores saved server passwords securely",
                        status: .granted
                    )
                }
            }
        }
        .onAppear {
            loadAuthorizedFolders()
            checkFullDiskAccess()
        }
    }

    // MARK: - Folder Row

    private func folderRow(_ folder: AuthorizedFolder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(folder.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(folder.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Status
            Image(systemName: folder.isAccessible ? "checkmark.circle" : "xmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(folder.isAccessible ? Color.green : Color.red)
                .help(folder.isAccessible ? "Accessible" : "Bookmark expired — re-authorize")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .onHover { hoveredFolderID = $0 ? folder.id : nil }
    }

    // MARK: - Permission Row

    enum PermissionStatus { case granted, denied, unknown }

    private func permissionRow(icon: String, title: String, description: String, status: PermissionStatus) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(description).font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Spacer()

            switch status {
            case .granted:
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
            case .denied:
                Button("Enable") { openFullDiskAccessSettings() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.orange)
            case .unknown:
                Text("Not checked")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Group Box

    private func paneGroupBox<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
    }

    // MARK: - Logic

    private func loadAuthorizedFolders() {
        // Read stored bookmark paths from UserDefaults directly
        let dict = (UserDefaults.standard.dictionary(forKey: "FavoritesKit.Bookmarks.v1") as? [String: Data]) ?? [:]
        authorizedFolders = dict.keys.sorted().map { path in
            let accessible = FileManager.default.isReadableFile(atPath: path)
            return AuthorizedFolder(
                id: UUID(),
                path: path,
                displayName: URL(fileURLWithPath: path).lastPathComponent,
                isAccessible: accessible
            )
        }
    }

    private func addFolder() {
        Task { @MainActor in
            let granted = await BookmarkStore.shared.requestAccessPersisting(for: URL(fileURLWithPath: "/"))
            if granted { loadAuthorizedFolders() }
            log.info("[Permissions] addFolder granted=\(granted)")
        }
    }

    private func removeSelectedFolder() {
        guard let last = authorizedFolders.last else { return }
        // Remove from UserDefaults directly (BookmarkStore has no remove API yet)
        var dict = (UserDefaults.standard.dictionary(forKey: "FavoritesKit.Bookmarks.v1") as? [String: Data]) ?? [:]
        dict.removeValue(forKey: last.path)
        UserDefaults.standard.set(dict, forKey: "FavoritesKit.Bookmarks.v1")
        loadAuthorizedFolders()
        log.info("[Permissions] removed folder '\(last.path)'")
    }

    private func checkFullDiskAccess() {
        isCheckingAccess = true
        Task.detached {
            // Probe /Library/Application Support — blocked without Full Disk Access
            let probe = "/Library/Application Support"
            let accessible = FileManager.default.isReadableFile(atPath: probe)
            await MainActor.run {
                hasFullDiskAccess = accessible
                isCheckingAccess = false
            }
        }
    }

    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - AuthorizedFolder model

struct AuthorizedFolder: Identifiable {
    let id: UUID
    let path: String
    let displayName: String
    let isAccessible: Bool
}
