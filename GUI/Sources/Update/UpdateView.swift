// UpdateView.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Update available dialog — shows release notes and download options.

import SwiftUI

// MARK: - UpdateView
struct UpdateView: View {
    @ObservedObject var checker = UpdateChecker.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            
            if checker.isChecking {
                checkingSection
            } else if let error = checker.error {
                errorSection(error)
            } else if checker.updateAvailable, let release = checker.latestRelease {
                updateAvailableSection(release)
            } else {
                upToDateSection
            }
            
            Divider()
            buttonSection
        }
        .frame(width: 480, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Software Update")
                    .font(.system(size: 16, weight: .light))
                Text("Current version: \(checker.currentVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }
    
    // MARK: - Checking
    private var checkingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Checking for updates...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error
    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Could not check for updates")
                .font(.headline)
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Up to Date
    private var upToDateSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("MiMiNavigator is up to date")
                .font(.headline)
            Text("Version \(checker.currentVersion) is the latest version.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Update Available
    private func updateAvailableSection(_ release: GitHubRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.accent)
                Text("Version \(release.tagName) is available!")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                if let asset = checker.downloadAsset {
                    Text(formatSize(asset.size))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Text("Release Notes:")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            ScrollView {
                Text(release.body.isEmpty ? "No release notes." : release.body)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func formatSize(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    // MARK: - Buttons
    private var buttonSection: some View {
        HStack(spacing: 12) {
            if checker.updateAvailable {
                Button("View on GitHub") {
                    checker.openReleasePage()
                }
                
                Spacer()
                
                Button("Download Update") {
                    checker.downloadUpdate()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Spacer()
                
                Button("Check Again") {
                    Task { await checker.checkForUpdates() }
                }
                .disabled(checker.isChecking)
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
    }
}

// MARK: - Preview
#Preview {
    UpdateView()
}
