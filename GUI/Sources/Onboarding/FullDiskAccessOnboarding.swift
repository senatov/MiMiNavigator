// FullDiskAccessOnboarding.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 09.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: First-launch sheet — requests full-disk access via a single
//   NSOpenPanel pointed at "/". One click grants the file manager access to
//   the entire filesystem instead of spamming per-folder TCC dialogs.
//   Remembers completion so it never shows again.

import AppKit
import SwiftUI


// MARK: - ════════════════════════════════════════════
// MARK:   Full Disk Access Onboarding
// MARK: - ════════════════════════════════════════════

struct FullDiskAccessOnboarding: View {

    @Binding var isPresented: Bool
    @State private var accessGranted = false
    @State private var showError     = false

    private static let completedKey = "FullDiskAccessOnboardingCompleted"


    var body: some View {
        VStack(spacing: 20) {
            header
            explanation
            statusBadge
            buttons
        }
        .padding(28)
        .frame(width: 460)
        .onAppear { checkExistingAccess() }
    }


    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text("Full Disk Access")
                .font(.system(size: 18, weight: .semibold))
            Text("MiMiNavigator is a file manager — it needs access to your entire disk to browse, copy, and compare files across all folders.")
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
                    "Grant access once to the root folder — covers everything.")
            infoRow("lock.shield",
                    "You can revoke access anytime in System Settings → Privacy.")
            infoRow("exclamationmark.triangle",
                    "Without access, macOS will ask permission for each protected folder separately.")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
    }


    // MARK: - Status badge

    private var statusBadge: some View {
        Group {
            if accessGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Full disk access granted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                }
            } else if showError {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.orange)
                    Text("Access was not granted — you can try again or skip for now.")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
        }
    }


    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 12) {
            DownToolbarButtonView(title: "System Settings", systemImage: "gearshape") {
                openFullDiskAccessSettings()
            }
            .help("Open Privacy → Full Disk Access in System Settings")
            Spacer()
            if accessGranted {
                DownToolbarButtonView(title: "Done", systemImage: "checkmark.circle") {
                    markComplete()
                    isPresented = false
                }
                .keyboardShortcut(.return)
            } else {
                DownToolbarButtonView(title: "Grant Access…", systemImage: "lock.open") {
                    requestFullDiskAccess()
                }
                .keyboardShortcut(.return)
            }
            DownToolbarButtonView(title: "Skip", systemImage: "forward") {
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


    private func checkExistingAccess() {
        let rootURL = URL(fileURLWithPath: "/")
        Task {
            let has = await BookmarkStore.shared.hasAccess(to: rootURL)
            accessGranted = has
        }
    }


    private func requestFullDiskAccess() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/")
        panel.message = "Select the root folder '/' to grant MiMiNavigator full disk access"
        panel.prompt = "Grant Access"
        panel.treatsFilePackagesAsDirectories = true
        let response = panel.runModal()
        guard response == .OK, let picked = panel.url else {
            showError = true
            return
        }
        Task {
            let ok = await BookmarkStore.shared.persistAccess(for: picked)
            if ok {
                accessGranted = true
                showError = false
                log.info("[FullDiskAccess] user granted access to \(picked.path)")
            } else {
                showError = true
                log.warning("[FullDiskAccess] persistAccess failed for \(picked.path)")
            }
        }
    }


    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
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
