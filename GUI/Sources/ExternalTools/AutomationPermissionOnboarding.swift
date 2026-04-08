// AutomationPermissionOnboarding.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: First-launch sheet — asks user to grant Automation permission once.
//   Shows what we need access to and why, with "Grant Access" + "Open System Settings" buttons.
//   Remembers dismissal so it never shows again after first OK.

import AppKit
import SwiftUI


// MARK: - AutomationPermissionOnboarding

struct AutomationPermissionOnboarding: View {

    @Binding var isPresented: Bool
    @State private var statuses: [(id: String, name: String, status: AutomationPermissionStatus)] = []
    @State private var allGranted = false


    var body: some View {
        VStack(spacing: 20) {
            // Icon + Title
            VStack(spacing: 10) {
                Image(systemName: "hand.raised.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.orange)
                Text("Automation Permission")
                    .font(.system(size: 18, weight: .semibold))
                Text("MiMiNavigator needs permission to communicate with Finder and System Events for features like Reveal in Finder and directory comparison tools.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 380)
            }

            // Permission rows
            VStack(spacing: 0) {
                ForEach(statuses, id: \.id) { item in
                    permissionRow(item)
                    if item.id != statuses.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))

            // Explanation
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Text("macOS will show a confirmation dialog for each app. After you approve once, it won't ask again.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Open System Settings") {
                    SystemSettingsHelper.openAutomation()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                Spacer()
                if allGranted {
                    Button("Done") {
                        markOnboardingComplete()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.return)
                } else {
                    Button("Grant Access") {
                        grantAll()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.regular)
                    .keyboardShortcut(.return)
                }
                Button("Skip") {
                    markOnboardingComplete()
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .keyboardShortcut(.escape)
            }
        }
        .padding(28)
        .frame(width: 440)
        .onAppear { refreshStatuses() }
    }


    // MARK: - Row

    private func permissionRow(_ item: (id: String, name: String, status: AutomationPermissionStatus)) -> some View {
        HStack(spacing: 12) {
            statusIcon(item.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                Text(item.id)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusLabel(item.status)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }


    private func statusIcon(_ s: AutomationPermissionStatus) -> some View {
        ZStack {
            Circle()
                .fill(s == .authorized ? Color.green.opacity(0.15) :
                        s == .denied ? Color.red.opacity(0.15) :
                        Color.orange.opacity(0.15))
                .frame(width: 24, height: 24)
            Image(systemName: s == .authorized ? "checkmark.circle.fill" :
                    s == .denied ? "xmark.circle.fill" :
                    "questionmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(s == .authorized ? Color.green :
                                    s == .denied ? Color.red :
                                    Color.orange)
        }
    }


    private func statusLabel(_ s: AutomationPermissionStatus) -> some View {
        Text(s == .authorized ? "Granted" : s == .denied ? "Denied" : "Not asked")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(s == .authorized ? Color.green : s == .denied ? Color.red : Color.orange)
    }


    // MARK: - Actions

    private func refreshStatuses() {
        statuses = AutomationPermissionChecker.targetBundleIDs.map { target in
            (id: target.id, name: target.name, status: AutomationPermissionChecker.checkPermission(for: target.id))
        }
        allGranted = statuses.allSatisfy { $0.status == .authorized }
    }


    private func grantAll() {
        for target in AutomationPermissionChecker.targetBundleIDs {
            if AutomationPermissionChecker.checkPermission(for: target.id) != .authorized {
                AutomationPermissionChecker.requestPermission(for: target.id)
            }
        }
        // re-check after a short delay (TCC dialog is modal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshStatuses()
        }
    }


    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "AutomationOnboardingCompleted")
    }


    static var needsOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: "AutomationOnboardingCompleted")
    }
}
