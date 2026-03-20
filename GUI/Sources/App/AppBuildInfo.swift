//
//  AppBuildInfo.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Build info toolbar item and version string helpers.
//               Extracted from MiMiNavigatorApp.swift.

import SwiftUI

// MARK: - AppBuildInfo
/// Provides the build-info toolbar badge and version Text helpers.
/// Used by MiMiNavigatorApp to avoid polluting the @main App struct.
enum AppBuildInfo {

    // MARK: - toolBarItem
    /// ToolbarItem with cat icon + DEV BUILD badge showing current version.
    @MainActor
    static func toolBarItem() -> ToolbarItem<(), some View> {
        ToolbarItem(placement: .status) {
            HStack(spacing: 8) {
                Text("🐈")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial) // glass effect
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.9), Color.orange.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .drawingGroup() // improves rendering sharpness
                VStack(alignment: .leading, spacing: 1) {
                    Text("DEV BUILD")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    versionText()
                        .font(.caption2)
                        .foregroundStyle(ColorThemeStore.shared.activeTheme.dirNameColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial) // glass container
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.blue.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .help("Current development build version")
        }
    }

    // MARK: - versionText
    /// Version Text read from curr_version.asc bundle resource, falls back to plist keys.
    static func versionText() -> Text {
        if let url = Bundle.main.url(forResource: "curr_version", withExtension: "asc"),
           let raw = try? String(contentsOf: url, encoding: .utf8)
        {
            return Text(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (s?, b?): return Text("v\(s) (\(b))")
        case let (s?, nil): return Text("v\(s)")
        case let (nil, b?): return Text("build \(b)")
        default:
            log.error("failed to load version")
            return Text("MiMi Navigator — cannot determine version")
        }
    }
}
