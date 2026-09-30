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
    /// ToolbarItem with TEST BUILD badge and optional resource graphs.
    @MainActor
    static func toolBarItem() -> ToolbarItem<(), some View> {
        ToolbarItem(placement: .status) {
            BuildInfoToolbarCluster(version: versionString())
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

// MARK: - Build Info Toolbar Cluster
private struct BuildInfoToolbarCluster: View {
    let version: String
    @State private var prefs = UserPreferences.shared

    private var showMemory: Bool { prefs.snapshot.toolbarShowMemoryGraph ?? true }
    private var showThreads: Bool { prefs.snapshot.toolbarShowThreadsGraph ?? true }
    private var memoryInterval: TimeInterval { prefs.snapshot.toolbarMemoryGraphInterval ?? 5 }
    private var threadsInterval: TimeInterval { prefs.snapshot.toolbarThreadsGraphInterval ?? 10 }

    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            DevBuildBadge(version: version)
            if showMemory || showThreads {
                ResourceMonitorToolbarItem(
                    showMemory: showMemory,
                    showThreads: showThreads,
                    memoryInterval: memoryInterval,
                    threadsInterval: threadsInterval
                )
                    .offset(y: 6)
            }
        }
    }
}

// MARK: - DevBuildBadge

private struct DevBuildBadge: View {
    let version: String
    @State private var center = InAppNoticeCenter.shared
    @State private var isRivetPulsing = false

    private var rivetColor: Color {
        isRivetPulsing ? center.historyRivetTint : Color(#colorLiteral(red: 1, green: 0.82, blue: 0.03, alpha: 1))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: -9) {
            badgeLabel
            Button {
                center.toggleHistory()
                log.info("[NoticeHistory] rivet clicked visible=\(center.isHistoryVisible)")
            } label: {
                GlossyNoticeRivet(color: rivetColor)
                    .frame(width: 25, height: 25)
                    .scaleEffect(isRivetPulsing ? 1.14 : 1)
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .zIndex(10)
            .help(center.isHistoryVisible ? "Hide recent messages" : "Show recent messages")
            .accessibilityLabel(center.isHistoryVisible ? "Hide recent messages" : "Show recent messages")
            .task(id: center.historyRivetPulse) {
                guard center.historyRivetPulse > 0 else { return }
                withAnimation(.easeOut(duration: 0.12)) { isRivetPulsing = true }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.28)) { isRivetPulsing = false }
            }
        }
        .frame(height: 46, alignment: .center)
        .offset(y: 6)
    }

    private var badgeLabel: some View {
        HStack(spacing: 8) {
            DevBuildCatMedallion()
            VStack(alignment: .leading, spacing: 1) {
                Text("TEST BUILD")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .tracking(0.5)
                    .foregroundStyle(Color.primary.opacity(0.90))
                Text(version)
                    .font(.system(size: 9, weight: .regular, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .background { TopToolbarSurface() }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help("Current test build version")
    }
}

// MARK: - Glossy Notice Rivet
private struct GlossyNoticeRivet: View {
    let color: Color

    // MARK: - Body
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [Color.white, Color.gray.opacity(0.95), Color.white, Color.gray.opacity(0.82), Color.white],
                        center: .center
                    )
                )
                .opacity(0.78)
            Circle()
                .strokeBorder(Color.black.opacity(0.58), lineWidth: 0.9)
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 0.8)
                .padding(1.2)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.72), color.opacity(0.61), color.opacity(0.49)],
                        center: .init(x: 0.38, y: 0.28),
                        startRadius: 0,
                        endRadius: 13
                    )
                )
                .padding(3.5)
            Circle()
                .strokeBorder(Color.black.opacity(0.72), lineWidth: 1)
                .padding(3.5)
            Ellipse()
                .fill(LinearGradient(colors: [Color.white.opacity(0.72), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                .frame(width: 13, height: 7)
                .offset(y: -5)
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 2.5, height: 2.5)
                .offset(x: -5.5, y: -5.5)
        }
        .shadow(color: Color.black.opacity(0.32), radius: 2, y: 1.5)
    }
}

// MARK: - DevBuildCatMedallion

private struct DevBuildCatMedallion: View {
    // MARK: - Body

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.ultraThickMaterial)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.92), Color.blue.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("🐈")
                .font(.system(size: 15))
                .fixedSize()
                .offset(y: -0.5)
        }
        .frame(width: 24, height: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white, Color.blue.opacity(0.22), Color.black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.75))
                .frame(width: 15, height: 0.75)
                .padding(.top, 1.5)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.14), radius: 1.75, x: 0, y: 1.25)
    }
}
