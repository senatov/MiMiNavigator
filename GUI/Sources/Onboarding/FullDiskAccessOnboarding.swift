// FullDiskAccessOnboarding.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 09.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: First-launch sheet — explains why Full Disk Access is needed
//   and opens the matching Privacy & Security pane for explicit user consent.
//   Remembers completion so it never shows again.

import AppKit
import SwiftUI


// MARK: - ════════════════════════════════════════════
// MARK:   Full Disk Access Onboarding
// MARK: - ════════════════════════════════════════════

struct FullDiskAccessOnboarding: View {

    @Binding var isPresented: Bool
    @State private var folderAccessError: String?

    private static let completedKey = "FullDiskAccessOnboardingCompleted"


    var body: some View {
        VStack(spacing: 20) {
            header
            explanation
            buttons
        }
        .padding(28)
        .frame(width: 460)
    }


    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text("Full Disk Access")
                .font(.system(size: 18, weight: .semibold))
            Text("Full Disk Access lets MiMiNavigator browse protected locations across your Mac. It is optional: you can authorize selected folders or continue with the locations already available to the app.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
        }
    }


    // MARK: - Explanation

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("folder.badge.gearshape",
                    "Full Disk Access unlocks protected locations such as Desktop, Documents, and app data.")
            infoRow("folder.badge.plus",
                    "Choose Folders saves access only to the folders you select.")
            infoRow("lock.shield",
                    "You can change Full Disk Access in System Settings or manage saved folders in MiMiNavigator Settings.")
            infoRow("exclamationmark.triangle",
                    "Restart MiMiNavigator after changing the permission.")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color(nsColor: .separatorColor).opacity(0.85), lineWidth: 1))
    }


    // MARK: - Buttons

    private var buttons: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if let folderAccessError {
                Text(folderAccessError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                DownToolbarButtonView(title: "Choose Folders…", systemImage: "folder.badge.plus") {
                    chooseFolders()
                }
                .keyboardShortcut(.return)
                DownToolbarButtonView(title: "Full Disk Access…", systemImage: "lock.open") {
                    requestFullDiskAccess()
                }
                .help("Open Privacy & Security → Full Disk Access in System Settings")
            }
            DownToolbarButtonView(title: "Continue without access", systemImage: "forward") {
                markComplete()
                isPresented = false
            }
            .keyboardShortcut(.escape)
        }
    }


    // MARK: - Helpers

    private func infoRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }


    // MARK: - Request Full Disk Access

    private func requestFullDiskAccess() {
        markComplete()
        isPresented = false
        SystemSettingsHelper.openFullDiskAccess()
    }

    // MARK: - Choose Authorized Folders
    private func chooseFolders() {
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
            guard response == .OK, !panel.urls.isEmpty else { return }
            var savedAny = false
            for url in panel.urls {
                savedAny = await BookmarkStore.shared.persistAccess(for: url) || savedAny
            }
            guard savedAny else {
                folderAccessError = "MiMiNavigator couldn't save access to those folders. Try again or continue without access."
                return
            }
            markComplete()
            isPresented = false
        }
    }


    private func markComplete() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
    }


    // MARK: - Static

    static var needsOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: completedKey)
    }
}
