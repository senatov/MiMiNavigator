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
    @State private var hoveredFolderID: String? = nil
    @State private var selectedFolderID: String? = nil

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

                    // +/- buttons + Add Entire Disk
                    HStack(spacing: 8) {
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
                            .disabled(selectedFolderID == nil)
                            .help("Remove selected folder permission")
                        }

                        Button {
                            addEntireDisk()
                        } label: {
                            Label("Add Entire Disk", systemImage: "internaldrive")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Grant access to the root volume via NSOpenPanel")
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
        let isSelected = selectedFolderID == folder.id
        return HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(folder.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Text(folder.path)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Image(systemName: folder.isAccessible ? "checkmark.circle" : "xmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(folder.isAccessible
                    ? (isSelected ? Color.white : Color.green)
                    : (isSelected ? Color.white : Color.red))
                .help(folder.isAccessible ? "Accessible" : "Bookmark expired — re-authorize")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedFolderID = folder.id }
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
                path: path,
                displayName: URL(fileURLWithPath: path).lastPathComponent,
                isAccessible: accessible
            )
        }
    }

    private func addFolder() {
        Task { @MainActor in
            let granted = await BookmarkStore.shared.requestAccessPersisting(for: URL(fileURLWithPath: NSHomeDirectory()))
            if granted { loadAuthorizedFolders() }
            log.info("[Permissions] addFolder granted=\(granted)")
        }
    }

    /// Open NSOpenPanel pre-navigated to the root volume so the user can select "/"
    /// and grant a security-scoped bookmark for the entire disk.
    private func addEntireDisk() {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = false
            panel.showsHiddenFiles = true
            panel.treatsFilePackagesAsDirectories = true
            // Navigate to the root volume
            panel.directoryURL = URL(fileURLWithPath: "/Volumes")
            panel.message = "Select the root disk (e.g. \"Macintosh HD\") to grant full access"
            panel.prompt = "Grant Access"

            let response = panel.runModal()
            guard response == .OK, let selectedURL = panel.urls.first else {
                log.info("[Permissions] addEntireDisk: user cancelled")
                return
            }

            let granted = await BookmarkStore.shared.persistAccess(for: selectedURL)
            if granted { loadAuthorizedFolders() }
            log.info("[Permissions] addEntireDisk: selected=\(selectedURL.path) granted=\(granted)")
        }
    }

    private func removeSelectedFolder() {
        guard let selID = selectedFolderID,
              let folder = authorizedFolders.first(where: { $0.id == selID }) else { return }
        var dict = (UserDefaults.standard.dictionary(forKey: "FavoritesKit.Bookmarks.v1") as? [String: Data]) ?? [:]
        dict.removeValue(forKey: folder.path)
        UserDefaults.standard.set(dict, forKey: "FavoritesKit.Bookmarks.v1")
        selectedFolderID = nil
        loadAuthorizedFolders()
        log.info("[Permissions] removed folder '\(folder.path)'")
    }

    private func checkFullDiskAccess() {
        isCheckingAccess = true
        Task {
            // Probe /Library/Application Support — blocked without Full Disk Access
            let probe = "/Library/Application Support"
            let accessible = await Task.detached { @concurrent in FileManager.default.isReadableFile(atPath: probe) }.value
            hasFullDiskAccess = accessible
            isCheckingAccess = false
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
    /// Stable ID based on path — consistent across reloads
    var id: String { path }
    let path: String
    let displayName: String
    let isAccessible: Bool
}
