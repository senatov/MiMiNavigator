// BreadCrumbView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.11.24.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Breadcrumb navigation bar.
//   Handles three path types:
//     • Local filesystem  — /Users/senat/Develop/…
//     • Archive (virtual) — archive.zip › subdir › …
//     • Remote (SFTP/FTP) — SFTP demo@host › /pub › docs
//   Smart truncation: middle segments shrink first, Finder-style
//   hover-expand reveals full name.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - BreadCrumbView
struct BreadCrumbView: View {

    @Environment(AppState.self) var appState
    let panelSide: FavPanelSide

    /// Use computed property to always get current theme (live updates)
    private var colorStore: ColorThemeStore { ColorThemeStore.shared }

    private let barHeight: CGFloat = 30
    private let separatorWidth: CGFloat = 10

    // MARK: - Active panel
    private var isActive: Bool { appState.focusedPanel == panelSide }

    private var textColor: Color {
        isActive
            ? colorStore.activeTheme.breadcrumbTextActive
            : colorStore.activeTheme.breadcrumbTextInactive
    }

    private var fontSize: CGFloat { colorStore.activeTheme.breadcrumbFontSize }

    private var panelURL: URL {
        appState.url(for: panelSide)
    }

    private var isInsideArchive: Bool {
        panelSide == .left
            ? appState.leftArchiveState.isInsideArchive
            : appState.rightArchiveState.isInsideArchive
    }

    private var archiveURL: URL? {
        panelSide == .left
            ? appState.leftArchiveState.archiveURL
            : appState.rightArchiveState.archiveURL
    }

    private var archiveTempDir: URL? {
        panelSide == .left
            ? appState.leftArchiveState.archiveTempDir
            : appState.rightArchiveState.archiveTempDir
    }

    private var activeRemoteConnection: RemoteConnection? {
        RemoteConnectionManager.shared.activeConnection
    }

    // MARK: - Init
    init(selectedSide: FavPanelSide) { self.panelSide = selectedSide }

    // MARK: - Body
    var body: some View {
        // Access themeVersion to create @Observable dependency for live updates
        let _ = ColorThemeStore.shared.themeVersion

        GeometryReader { geo in
            HStack(alignment: .center, spacing: 4) {
                ForEach(Array(visibleSegments(for: geo.size.width).enumerated()), id: \.offset) { idx, seg in
                    breadcrumbItem(segment: seg, index: idx)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: barHeight, alignment: .leading)
        }
        .padding(.horizontal, 0)
        .focusable(false)
        .frame(height: barHeight)
        .controlSize(.mini)
    }

    // MARK: - pathComponents
    /// Returns segments to display. Three modes:
    ///   remote  → ["SFTP demo@host", "pub", "docs"]   (first segment = origin label)
    ///   archive → ["archive.zip", "subdir"]
    ///   local   → ["/", "Users", "senat", "Develop"]
    var pathComponents: [BreadCrumbDisplayComponent] {
        let panelURL = panelURL

        // ── Remote (SFTP / FTP) ──────────────────────────────────────────────
        if AppState.isRemotePath(panelURL) {
            return remoteComponents(for: panelURL).map {
                BreadCrumbDisplayComponent(text: $0, isEnvironmentVariable: false)
            }
        }

        // ── Archive (virtual) ────────────────────────────────────────────────
        if isInsideArchive,
            let archiveURL,
            let tempDir = archiveTempDir
        {
            return archiveComponents(
                currentPath: panelURL.path,
                archiveName: archiveURL.lastPathComponent,
                tempDir: tempDir.standardizedFileURL.path
            ).map { BreadCrumbDisplayComponent(text: $0, isEnvironmentVariable: false) }
        }

        // ── Local filesystem ─────────────────────────────────────────────────
        let displayPath = appState.breadcrumbDisplayPath(for: panelSide)
        var components = PathEnvironmentResolver.displayComponents(from: displayPath)
        // Prepend filesystem root so the breadcrumb visually starts with "/"
        if displayPath.hasPrefix("/") || displayPath.hasPrefix("$") {
            components.insert(
                BreadCrumbDisplayComponent(text: "/", isEnvironmentVariable: false),
                at: 0
            )
        }
        return components
    }

    private var pathComponentTexts: [String] {
        pathComponents.map(\.text)
    }

    private var localDisplayPath: String {
        appState.breadcrumbDisplayPath(for: panelSide)
    }

    private func makeLocalDisplayPath(through index: Int) -> String {
        let joined = pathComponentTexts.prefix(index + 1).joined(separator: "/")
        return localDisplayPath.hasPrefix("/") ? "/" + joined : joined
    }

    // MARK: - remoteComponents
    /// First segment = "PROTO user@host[:port]", rest = path components.
    /// Example: sftp://demo@test.rebex.net/pub/docs
    ///          → ["SFTP demo@test.rebex.net", "pub", "docs"]
    private func remoteComponents(for url: URL) -> [String] {
        let originLabel: String
        let remotePath: String

        if let connection = activeRemoteConnection {
            let origin = AppState.remoteOrigin(from: connection.provider.mountPath)
            originLabel = formatOriginLabel(origin)
            remotePath = connection.currentPath
        } else {
            originLabel = formatOriginLabel(url.absoluteString)
            remotePath = url.path
        }

        let pathParts = pathParts(from: remotePath)
        return [originLabel] + pathParts
    }

    private func pathParts(from path: String) -> [String] {
        path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: - formatOriginLabel
    /// "sftp://demo@test.rebex.net" → "SFTP demo@test.rebex.net"
    /// "ftp://user@host:21"         → "FTP user@host"  (default port stripped)
    private func formatOriginLabel(_ raw: String) -> String {
        guard let url = URL(string: raw),
            let scheme = url.scheme,
            let host = url.host
        else { return raw }

        let protoLabel = scheme.uppercased()
        let userPart = url.user.map { "\($0)@" } ?? ""
        let portPart: String
        if let port = url.port,
            !((scheme == "sftp" && port == 22) || (scheme == "ftp" && port == 21)
                || (scheme == "smb" && port == 445) || (scheme == "afp" && port == 548))
        {
            portPart = ":\(port)"
        } else {
            portPart = ""
        }
        return "\(protoLabel) \(userPart)\(host)\(portPart)"
    }

    // MARK: - archiveComponents
    private func archiveComponents(currentPath: String, archiveName: String, tempDir: String) -> [String] {
        let normalizedCurrent = URL(fileURLWithPath: currentPath).standardizedFileURL.path
        var relative = ""
        if normalizedCurrent.hasPrefix(tempDir) {
            relative = String(normalizedCurrent.dropFirst(tempDir.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if relative.isEmpty { return [archiveName] }
        return [archiveName] + relative.split(separator: "/").map(String.init)
    }

    private func remoteTargetPath(for segment: DisplaySegment) -> String? {
        guard let connection = activeRemoteConnection else { return nil }

        let origin = AppState.remoteOrigin(from: connection.provider.mountPath)
        if segment.originalIndex == 0 {
            return origin + "/"
        }

        let parts = Array(pathComponentTexts[1...segment.originalIndex])
        return origin + "/" + parts.joined(separator: "/")
    }

    private func archiveTargetPath(for segment: DisplaySegment) -> String? {
        guard let tempDir = archiveTempDir else { return nil }
        guard segment.originalIndex > 0 else { return nil }

        let sub = Array(pathComponentTexts[1...segment.originalIndex])
        return tempDir.standardizedFileURL.path + "/" + sub.joined(separator: "/")
    }

    private func localTargetPath(for segment: DisplaySegment) -> String {
        makeLocalDisplayPath(through: segment.originalIndex)
            .replacingOccurrences(of: "//", with: "/")
    }

    // MARK: - breadcrumbItem
    @ViewBuilder
    private func breadcrumbItem(segment: DisplaySegment, index: Int) -> some View {
        if segment.showsSeparatorBefore {
            Text("/")
                .foregroundStyle(.secondary)
                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                .padding(.horizontal, 1)
        }
        ExpandableSegmentButton(
            segment: segment,
            textColor: textColor,
            variableTextColor: colorStore.activeTheme.breadcrumbVariableColor,
            variableItalic: colorStore.breadcrumbVariableItalic,
            fontSize: fontSize,
            onTap: { handleTap(segment: segment) },
            helpText: tooltip(for: segment),
            copyAction: { copyPath(for: segment) }
        )
    }

    // MARK: - handleTap
    private func handleTap(segment: DisplaySegment) {
        log.info("[BreadCrumb] tap index=\(segment.originalIndex) on \(panelSide)")

        let targetPath: String

        if AppState.isRemotePath(panelURL) {
            guard let remotePath = remoteTargetPath(for: segment) else { return }
            targetPath = remotePath
        } else if isInsideArchive {
            if segment.originalIndex == 0 {
                Task { await appState.exitArchive(on: panelSide) }
                return
            }
            guard let archivePath = archiveTargetPath(for: segment) else { return }
            targetPath = archivePath
        } else {
            targetPath = localTargetPath(for: segment)
        }

        Task {
            await PathNavigationService.shared(appState: appState)
                .navigate(to: targetPath, side: panelSide)
        }
    }

    // MARK: - tooltip
    private func tooltip(for segment: DisplaySegment) -> String {
        if AppState.isRemotePath(panelURL) {
            if segment.originalIndex == 0 {
                return "🌐 \(segment.fullName) — tap to go to root"
            }
            let parts = Array(pathComponentTexts[1...segment.originalIndex])
            return "📂 /\(parts.joined(separator: "/"))"
        }

        if isInsideArchive {
            if segment.originalIndex == 0 {
                return "📦 \(segment.fullName) — tap to exit archive"
            }
            let parts = pathComponentTexts.prefix(segment.originalIndex + 1)
            return "📂 \(parts.joined(separator: "/"))"
        }

        let fullPath = makeLocalDisplayPath(through: segment.originalIndex)
        return "📂 Open \(fullPath)"
    }

    private func remoteCopyPath(for segment: DisplaySegment) -> String {
        if segment.originalIndex == 0 {
            return
                activeRemoteConnection
                .map { AppState.remoteOrigin(from: $0.provider.mountPath) }
                ?? segment.fullName
        }

        let parts = Array(pathComponentTexts[1...segment.originalIndex])
        return "/" + parts.joined(separator: "/")
    }

    private func archiveCopyPath(for segment: DisplaySegment) -> String {
        if segment.originalIndex == 0 {
            return archiveURL?.path ?? ""
        }

        guard let tempDir = archiveTempDir else { return "" }
        let sub = Array(pathComponentTexts[1...segment.originalIndex])
        return tempDir.standardizedFileURL.path + "/" + sub.joined(separator: "/")
    }

    // MARK: - copyPath
    /// Copies the current panel's real filesystem path to clipboard.
    private func copyPath(for segment: DisplaySegment) {
        let pathToCopy: String

        if AppState.isRemotePath(panelURL) {
            pathToCopy = remoteCopyPath(for: segment)
        } else if isInsideArchive {
            pathToCopy = archiveCopyPath(for: segment)
        } else {
            pathToCopy = panelURL.path
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pathToCopy, forType: .string)
        log.debug("[BreadCrumb] copied: \(pathToCopy)")
    }
}
