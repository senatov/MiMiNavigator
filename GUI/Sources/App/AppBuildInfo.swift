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
                    .font(.system(size: 14))
                    .padding(7)
                    .background(
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.95), Color(white: 0.88)],
                                startPoint: .top, endPoint: .bottom))
                            .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1))
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.5)],
                                    startPoint: .top, endPoint: .bottom),
                                lineWidth: 1.5))
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
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.6), Color(white: 0.94)],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        Color(red: 0.15, green: 0.25, blue: 0.5).opacity(0.6),
                        lineWidth: 1))
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
