//
//  SelectionStatusBar.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 05.02.2026.
//  Description: Bottom status bar for each file panel.
//  Shows disk space / marked files info, filter bar, jump controls and position indicator.
//

import FileModelKit
import SwiftUI

// MARK: - Selection Status Bar
/// Bottom information bar displayed under each file panel.
struct SelectionStatusBar: View {

    // MARK: - Environment

    @Environment(AppState.self) private var appState

    // MARK: - Inputs

    let panelSide: FavPanelSide

    private var isLeftPanel: Bool {
        panelSide == .left
    }

    private var currentPath: String {
        currentURL.path
    }

    // MARK: - State

    @State private var colorStore = ColorThemeStore.shared
    @State private var viewModeStore = PanelViewModeStore.shared

    // MARK: - Derived Data

    /// Number of marked files
    private var markedCount: Int {
        appState.markedCount(for: panelSide)
    }

    /// Total size of marked files
    private var markedSize: Int64 {
        appState.markedTotalSize(for: panelSide)
    }

    /// Number of displayed files (excluding ".." parent directory entry)
    private var totalFiles: Int {
        appState.displayedFiles(for: panelSide)
            .filter { !ParentDirectoryEntry.isParentEntry($0) }
            .count
    }

    /// Current URL for this panel
    private var currentURL: URL {
        isLeftPanel ? appState.leftURL : appState.rightURL
    }

    /// Selected file index (1‑based). 0 if nothing selected.
    /// Cached by AppState → O(1)
    private var selectedIndex: Int {
        appState.selectedIndex(for: panelSide)
    }

    /// Formatted size of marked files
    private var formattedMarkedSize: String {
        formatFileSize(markedSize)
    }

    /// Active remote connection (if panel path is remote)
    private var remoteConnection: RemoteConnection? {
        guard AppState.isRemotePath(currentURL) else { return nil }
        return RemoteConnectionManager.shared.activeConnection
    }

    private var isMountedVolumeRoot: Bool {
        let normalized = NSString(string: currentPath).standardizingPath
        guard normalized.hasPrefix("/Volumes/"), normalized != "/Volumes" else { return false }
        return normalized.split(separator: "/").count == 2
    }

    /// Filter binding for the current panel
    private var filterQuery: Binding<String> {
        Binding(
            get: {
                isLeftPanel
                    ? appState.leftFilterQuery
                    : appState.rightFilterQuery
            },
            set: { newValue in
                if isLeftPanel {
                    appState.leftFilterQuery = newValue
                } else {
                    appState.rightFilterQuery = newValue
                }
            }
        )
    }

    // MARK: - Disk Space

    /// Available disk space for the current path
    private var availableDiskSpace: String {
        if let capacity = availableCapacityFromResourceValues(for: currentURL) {
            return formatFileSize(capacity)
        }

        if isMountedVolumeRoot {
            return "—"
        }

        if let free = availableCapacityFromFileSystemAttributes(forPath: currentPath) {
            return formatFileSize(free)
        }

        return "—"
    }

    private func formatFileSize(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private func availableCapacityFromResourceValues(for url: URL) -> Int64? {
        guard
            let values = try? url.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
            ])
        else {
            return nil
        }

        if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
            return important
        }

        if let basic = values.volumeAvailableCapacity, basic > 0 {
            return Int64(basic)
        }

        return nil
    }

    private func availableCapacityFromFileSystemAttributes(forPath path: String) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path),
            let free = attrs[.systemFreeSize] as? Int64,
            free > 0
        else {
            return nil
        }

        return free
    }

    private var diskSpaceLabel: String {
        availableDiskSpace == "—"
            ? "Free space unavailable"
            : "\(availableDiskSpace) free"
    }

    // MARK: - Body

    var body: some View {

        HStack(spacing: 8) {

            leftInfoSection

            remoteBadgeSection

            filterSection

            Spacer()

            thumbnailSliderSection

            positionIndicator
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.15), value: viewModeStore.mode(for: panelSide))
        .animation(.easeInOut(duration: 0.15), value: markedCount)
    }

}

// MARK: - Sections
extension SelectionStatusBar {

    private var leftInfoSection: some View {

        Group {
            if markedCount > 0 {

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(colorStore.activeTheme.markedCountColor)

                    Text(L10n.Selection.markedCount(markedCount))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(colorStore.activeTheme.markedCountColor)
                }

                Text("•")
                    .foregroundStyle(.secondary)

                Text(L10n.Selection.markedSize(formattedMarkedSize))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

            } else {

                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Text(diskSpaceLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var remoteBadgeSection: some View {

        Group {
            if let conn = remoteConnection {

                HStack(spacing: 3) {

                    Image(
                        systemName:
                            conn.protocolType == .sftp
                            ? "lock.shield"
                            : "globe"
                    )
                    .font(.system(size: 9))

                    Text(conn.server.host)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(
                            conn.protocolType == .sftp
                                ? Color.green.opacity(0.15)
                                : Color.blue.opacity(0.15)
                        )
                )
                .foregroundStyle(
                    conn.protocolType == .sftp
                        ? .green
                        : .blue
                )
            }
        }
    }

    private var filterSection: some View {

        PanelFilterBar(query: filterQuery, panelSide: panelSide)
            .frame(minWidth: 140, maxWidth: 220)
    }

    private var thumbnailSliderSection: some View {

        Group {
            if viewModeStore.mode(for: panelSide) == .thumbnail {
                ThumbnailSizeSlider(
                    value: Binding(
                        get: { viewModeStore.thumbSize(for: panelSide) },
                        set: { viewModeStore.setThumbSize($0, for: panelSide) }
                    ),
                    range: 16...900,
                    accentColor: colorStore.activeTheme.accentColor
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }

    private var positionIndicator: some View {

        Group {

            if selectedIndex > 0 {

                Text("\(selectedIndex) / \(totalFiles)")
                    .monospacedDigit()
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

            } else {

                Text("\(totalFiles) items")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

}

// MARK: - Jump Notifications
extension Notification.Name {

    static let jumpToFirst = Notification.Name("MiMi.jumpToFirst")
    static let jumpToLast = Notification.Name("MiMi.jumpToLast")
}
