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
    private let separatorWidth: CGFloat = 20

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

    private var archiveState: ArchiveState {
        panelSide == .left ? appState.leftArchiveState : appState.rightArchiveState
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

    // MARK: - DisplaySegment
    struct DisplaySegment: Identifiable {
        let id = UUID()
        let text: String  // shown (may be truncated)
        let fullName: String  // full name for tooltip + hover-expand
        let originalIndex: Int  // index in pathComponents for navigation
        var isTruncated: Bool { text != fullName }
    }

    // MARK: - pathComponents
    /// Returns segments to display. Three modes:
    ///   remote  → ["SFTP demo@host", "pub", "docs"]   (first segment = origin label)
    ///   archive → ["archive.zip", "subdir"]
    ///   local   → ["Users", "senat", "Develop"]
    private var pathComponents: [String] {
        let panelURL = panelURL

        // ── Remote (SFTP / FTP) ──────────────────────────────────────────────
        if AppState.isRemotePath(panelURL) {
            return remoteComponents(for: panelURL)
        }

        // ── Archive (virtual) ────────────────────────────────────────────────
        if archiveState.isInsideArchive,
            let archiveURL = archiveState.archiveURL,
            let tempDir = archiveState.archiveTempDir
        {
            return archiveComponents(
                currentPath: panelURL.path,
                archiveName: archiveURL.lastPathComponent,
                tempDir: tempDir.standardizedFileURL.path
            )
        }

        // ── Local filesystem ─────────────────────────────────────────────────
        return panelURL.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
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

    // MARK: - visibleSegments — smart truncation
    private func visibleSegments(for availableWidth: CGFloat) -> [DisplaySegment] {
        let components = pathComponents
        guard !components.isEmpty else { return [] }

        if components.count == 1 {
            return [DisplaySegment(text: components[0], fullName: components[0], originalIndex: 0)]
        }

        let charWidth: CGFloat = 7.5
        let totalSepWidth = CGFloat(components.count - 1) * separatorWidth
        let budgetForText = availableWidth - totalSepWidth - 16

        let widths = components.map { CGFloat($0.count) * charWidth }
        let totalWidth = widths.reduce(0, +)

        if totalWidth <= budgetForText {
            return components.enumerated()
                .map { i, name in
                    DisplaySegment(text: name, fullName: name, originalIndex: i)
                }
        }

        // Truncate: middle-first, by length
        struct Seg {
            var index: Int
            var name: String
            var display: String
            var width: CGFloat
            var priority: Int
        }
        var segs = components.enumerated()
            .map { i, name in
                Seg(
                    index: i, name: name, display: name, width: widths[i],
                    priority: truncPriority(index: i, total: components.count, len: name.count))
            }
        var used = totalWidth
        while used > budgetForText {
            guard
                let idx = segs.enumerated()
                    .filter({ $0.element.display.count > 3 })
                    .max(by: { $0.element.priority < $1.element.priority })?
                    .offset
            else { break }
            let old = segs[idx]
            let newDisplay = truncMiddle(old.display, maxLen: max(3, old.display.count - 4))
            let newWidth = CGFloat(newDisplay.count) * charWidth
            used -= old.width - newWidth
            segs[idx].display = newDisplay
            segs[idx].width = newWidth
            segs[idx].priority = 0
        }
        return segs.map { DisplaySegment(text: $0.display, fullName: $0.name, originalIndex: $0.index) }
    }

    // MARK: - truncPriority — never truncate first/last; longer middle first
    private func truncPriority(index: Int, total: Int, len: Int) -> Int {
        guard index != 0 && index != total - 1 else { return 0 }
        return len * 10
    }

    // MARK: - truncMiddle
    private func truncMiddle(_ s: String, maxLen: Int) -> String {
        guard s.count > maxLen, maxLen >= 3 else { return s }
        let half = (maxLen - 1) / 2
        return "\(s.prefix(half))…\(s.suffix(half))"
    }

    private func remoteTargetPath(for segment: DisplaySegment) -> String? {
        guard let connection = activeRemoteConnection else { return nil }

        let origin = AppState.remoteOrigin(from: connection.provider.mountPath)
        if segment.originalIndex == 0 {
            return origin + "/"
        }

        let parts = Array(pathComponents[1...segment.originalIndex])
        return origin + "/" + parts.joined(separator: "/")
    }

    private func archiveTargetPath(for segment: DisplaySegment) -> String? {
        guard let tempDir = archiveState.archiveTempDir else { return nil }
        guard segment.originalIndex > 0 else { return nil }

        let sub = Array(pathComponents[1...segment.originalIndex])
        return tempDir.standardizedFileURL.path + "/" + sub.joined(separator: "/")
    }

    private func localTargetPath(for segment: DisplaySegment) -> String {
        ("/" + pathComponents.prefix(segment.originalIndex + 1).joined(separator: "/"))
            .replacingOccurrences(of: "//", with: "/")
    }

    // MARK: - breadcrumbItem
    @ViewBuilder
    private func breadcrumbItem(segment: DisplaySegment, index: Int) -> some View {
        if index > 0 {
            Image(systemName: "arrowtriangle.forward.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(.system(size: 14, weight: .light, design: .rounded))
                .padding(.horizontal, 2)
        }
        ExpandableSegmentButton(
            segment: segment,
            textColor: textColor,
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
        } else if archiveState.isInsideArchive {
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
            let parts = Array(pathComponents[1...segment.originalIndex])
            return "📂 /\(parts.joined(separator: "/"))"
        }

        if archiveState.isInsideArchive {
            if segment.originalIndex == 0 {
                return "📦 \(segment.fullName) — tap to exit archive"
            }
            let parts = pathComponents.prefix(segment.originalIndex + 1)
            return "📂 \(parts.joined(separator: "/"))"
        }

        let fullPath = "/" + pathComponents.prefix(segment.originalIndex + 1).joined(separator: "/")
        return "📂 Open \(fullPath)"
    }

    private func remoteCopyPath(for segment: DisplaySegment) -> String {
        if segment.originalIndex == 0 {
            return activeRemoteConnection
                .map { AppState.remoteOrigin(from: $0.provider.mountPath) }
                ?? segment.fullName
        }

        let parts = Array(pathComponents[1...segment.originalIndex])
        return "/" + parts.joined(separator: "/")
    }

    private func archiveCopyPath(for segment: DisplaySegment) -> String {
        if segment.originalIndex == 0 {
            return archiveState.archiveURL?.path ?? ""
        }

        guard let tempDir = archiveState.archiveTempDir else { return "" }
        let sub = Array(pathComponents[1...segment.originalIndex])
        return tempDir.standardizedFileURL.path + "/" + sub.joined(separator: "/")
    }

    // MARK: - copyPath
    private func copyPath(for segment: DisplaySegment) {
        let pathToCopy: String

        if AppState.isRemotePath(panelURL) {
            pathToCopy = remoteCopyPath(for: segment)
        } else if archiveState.isInsideArchive {
            pathToCopy = archiveCopyPath(for: segment)
        } else {
            pathToCopy = "/" + pathComponents.prefix(segment.originalIndex + 1).joined(separator: "/")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pathToCopy, forType: .string)
        log.debug("[BreadCrumb] copied: \(pathToCopy)")
    }
}
