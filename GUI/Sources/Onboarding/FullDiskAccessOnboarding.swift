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
                    "Open System Settings and enable MiMiNavigator in Full Disk Access.")
            infoRow("lock.shield",
                    "Only you can grant or revoke this permission in macOS.")
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
        HStack(spacing: 12) {
            Spacer()
            DownToolbarButtonView(title: "Grant Access…", systemImage: "lock.open") {
                requestFullDiskAccess()
            }
            .help("Open Privacy & Security → Full Disk Access in System Settings")
            .keyboardShortcut(.return)
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


    // MARK: - Request Full Disk Access

    private func requestFullDiskAccess() {
        markComplete()
        isPresented = false
        SystemSettingsHelper.openFullDiskAccess()
    }


    private func markComplete() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
    }


    // MARK: - Static

    static var needsOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: completedKey)
    }
}
