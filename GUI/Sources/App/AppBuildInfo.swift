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
            DevBuildBadge(version: versionString())
        }
    }

    // MARK: - versionText
    /// Version Text read from curr_version.asc bundle resource, falls back to plist keys.
    static func versionText() -> Text {
        Text(versionString())
    }

    // MARK: - Version String

    static func versionString() -> String {
        if let url = Bundle.main.url(forResource: "curr_version", withExtension: "asc"),
           let raw = try? String(contentsOf: url, encoding: .utf8)
        {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (s?, b?): return "v\(s) (\(b))"
        case let (s?, nil): return "v\(s)"
        case let (nil, b?): return "build \(b)"
        default:
            log.error("failed to load version")
            return "MiMi Navigator — cannot determine version"
        }
    }
}

// MARK: - DevBuildBadge

private struct DevBuildBadge: View {
    let version: String

    // MARK: - Body

    var body: some View {
        HStack(spacing: 9) {
            DevBuildCatMedallion()
            VStack(alignment: .leading, spacing: 1) {
                Text("DEV BUILD")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.55)
                    .foregroundStyle(.primary.opacity(0.82))
                Text(version)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background { DevBuildBadgeSurface() }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help("Current development build version")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Development build \(version)")
    }
}

// MARK: - DevBuildCatMedallion

private struct DevBuildCatMedallion: View {
    // MARK: - Body

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThickMaterial)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.92), Color.blue.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("🐈")
                .font(.system(size: 19))
                .fixedSize()
                .offset(y: -0.5)
        }
        .frame(width: 31, height: 31)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white, Color.blue.opacity(0.22), Color.black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.75))
                .frame(width: 18, height: 0.8)
                .padding(.top, 1.5)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.18), radius: 2.25, x: 0, y: 1.75)
    }
}

// MARK: - DevBuildBadgeSurface

private struct DevBuildBadgeSurface: View {
    // MARK: - Body

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.blue.opacity(0.13))
                .offset(y: 2.25)
                .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 3)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.92), Color.white.opacity(0.62), Color.blue.opacity(0.055)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.52), Color.white.opacity(0.10), Color.clear],
                                center: UnitPoint(x: 0.42, y: 0.12),
                                startRadius: 1,
                                endRadius: 125
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white, Color.blue.opacity(0.25), Color.blue.opacity(0.56)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.78))
                        .frame(height: 0.9)
                        .padding(.horizontal, 10)
                        .padding(.top, 1.5)
                }
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(Color.blue.opacity(0.14))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 1)
                }
        }
    }
}
