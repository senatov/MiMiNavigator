// SettingsPermissionsPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Canonical macOS permission controls with distinct system and
//   security-scoped folder access sections.

import AppKit
import SwiftUI

// MARK: - Settings Permissions Pane

struct SettingsPermissionsPane: View {
    @State private var authorizedFolders: [AuthorizedFolder] = []
    @State private var selectedFolderID: String?
    @State private var showRestartBanner = false
    @State private var isRestarting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showRestartBanner {
                SettingsPermissionsRestartBanner(isRestarting: isRestarting) {
                    guard !isRestarting else { return }
                    isRestarting = true
                    NSApplication.shared.relaunch()
                }
            }
            fullDiskAccessCard
            authorizedFoldersCard
            accessGuideCard
        }
        .onAppear { loadAuthorizedFolders() }
    }

    // MARK: - Full Disk Access Card

    private var fullDiskAccessCard: some View {
        PermissionsGlassCard {
            HStack(alignment: .top, spacing: 16) {
                PermissionsDimensionalIcon(
                    systemName: "lock.shield.fill",
                    tint: SettingsVisualStyle.accent,
                    badgeSystemName: "gearshape.fill"
                )
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Full Disk Access")
                            .font(.system(size: 17, weight: .semibold))
                        PermissionsStatusCapsule(
                            title: "Managed by macOS",
                            systemName: "apple.logo",
                            tint: .secondary
                        )
                    }
                    Text("Allows MiMiNavigator to work with protected data across your Mac. macOS does not let apps enable this permission or reliably read its switch state.")
                        .font(.system(size: 12))
                        .foregroundStyle(SettingsVisualStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    PermissionsFeatureGrid(items: [
                        ("desktopcomputer", "Desktop & Documents"),
                        ("icloud.fill", "iCloud Drive"),
                        ("externaldrive.fill", "Removable volumes"),
                        ("folder.badge.gearshape", "Protected app data")
                    ])
                    HStack(spacing: 10) {
                        Button {
                            SystemSettingsHelper.openFullDiskAccess()
                        } label: {
                            Label("Open Full Disk Access Settings", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        Text("Enable MiMiNavigator, then restart the app.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Authorized Folders Card

    private var authorizedFoldersCard: some View {
        PermissionsGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    PermissionsDimensionalIcon(
                        systemName: "folder.fill",
                        tint: SettingsVisualStyle.accent,
                        badgeSystemName: "checkmark.seal.fill"
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text("Authorized Folders")
                                .font(.system(size: 17, weight: .semibold))
                            PermissionsStatusCapsule(
                                title: "\(authorizedFolders.count) saved",
                                systemName: "bookmark.fill",
                                tint: authorizedFolders.isEmpty ? .secondary : .green
                            )
                        }
                        Text("Optional folder-specific access stored as secure bookmarks. Use this for least-privilege access or when Full Disk Access is not enabled.")
                            .font(.system(size: 12))
                            .foregroundStyle(SettingsVisualStyle.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button {
                        addFolders()
                    } label: {
                        Label("Add Folders…", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
                folderList
                HStack {
                    Label("Folder permissions are independent from Full Disk Access.", systemImage: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsVisualStyle.secondaryText)
                    Spacer()
                    Button("Remove", systemImage: "minus") {
                        removeSelectedFolder()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(selectedFolderID == nil)
                }
            }
        }
    }

    // MARK: - Folder List

    private var folderList: some View {
        Group {
            if authorizedFolders.isEmpty {
                PermissionsEmptyFoldersView()
            } else {
                VStack(spacing: 0) {
                    ForEach(authorizedFolders) { folder in
                        PermissionsFolderRow(
                            folder: folder,
                            isSelected: selectedFolderID == folder.id
                        ) {
                            selectedFolderID = folder.id
                        }
                        if folder.id != authorizedFolders.last?.id {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                .background(.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Access Guide Card

    private var accessGuideCard: some View {
        PermissionsGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("How access works", systemImage: "questionmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                PermissionsAccessComparison()
            }
        }
    }

    // MARK: - Load Authorized Folders

    private func loadAuthorizedFolders() {
        let dict = (MiMiDefaults.shared.dictionary(forKey: "FavoritesKit.Bookmarks.v1") as? [String: Data]) ?? [:]
        authorizedFolders = dict.keys.sorted().map { path in
            AuthorizedFolder(
                path: path,
                displayName: URL(fileURLWithPath: path).lastPathComponent,
                isAccessible: FileManager.default.isReadableFile(atPath: path)
            )
        }
    }

    // MARK: - Add Folders

    private func addFolders() {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = false
            panel.showsHiddenFiles = true
            panel.treatsFilePackagesAsDirectories = true
            panel.directoryURL = URL(fileURLWithPath: "/")
            panel.message = "Choose folders that MiMiNavigator may access"
            panel.prompt = "Authorize"
            let response = await SystemPanelPresenter.response(for: panel)
            guard response == .OK, !panel.urls.isEmpty else {
                log.info("[Permissions] addFolders: user cancelled")
                return
            }
            for url in panel.urls {
                let granted = await BookmarkStore.shared.persistAccess(for: url)
                log.info("[Permissions] addFolders: \(url.path) granted=\(granted)")
            }
            loadAuthorizedFolders()
            showRestartBanner = true
        }
    }

    // MARK: - Remove Selected Folder

    private func removeSelectedFolder() {
        guard let selectedFolderID,
              let folder = authorizedFolders.first(where: { $0.id == selectedFolderID }) else { return }
        var dict = (MiMiDefaults.shared.dictionary(forKey: "FavoritesKit.Bookmarks.v1") as? [String: Data]) ?? [:]
        dict.removeValue(forKey: folder.path)
        MiMiDefaults.shared.set(dict, forKey: "FavoritesKit.Bookmarks.v1")
        self.selectedFolderID = nil
        loadAuthorizedFolders()
        log.info("[Permissions] removed folder '\(folder.path)'")
    }
}
