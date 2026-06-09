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
        markedFiles.count
    }

    /// Total size of marked files
    private var markedSize: Int64 {
        markedFiles.reduce(0) { $0 + $1.sizeInBytes }
    }

    private var markedStatusColor: Color {
        colorStore.activeTheme.markedFileColor
    }

    private var displayedPanelFiles: [CustomFile] {
        appState.displayedFiles(for: panelSide)
            .filter { !ParentDirectoryEntry.isParentEntry($0) && !$0.isDirectory }
    }

    private var markedFiles: [CustomFile] {
        let marked = appState.markedFiles(for: panelSide)
        return displayedPanelFiles.filter { marked.contains($0.id) }
    }

    /// Number of displayed files (excluding directories and ".." parent directory entry)
    private var totalFiles: Int {
        displayedPanelFiles.count
    }

    private var totalFilesSize: Int64 {
        displayedPanelFiles.reduce(0) { $0 + $1.sizeInBytes }
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
        formatKilobytes(markedSize)
    }

    private var markedStatusText: String {
        "\(formattedMarkedSize) / \(formatKilobytes(totalFilesSize)) in \(markedCount) / \(totalFiles) file(s)"
    }

    /// Active remote connection (if panel path is remote)
    private var remoteConnection: RemoteConnection? {
        guard AppState.isRemotePath(currentURL) else { return nil }
        return RemoteConnectionManager.shared.activeConnection
    }

    private var isMountedVolumeRoot: Bool {
        AppState.isMountedVolumeRootPath(currentPath)
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

    private func formatKilobytes(_ value: Int64) -> String {
        let kilobytes = max(0, Int((value + 1_023) / 1_024))
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: kilobytes)) ?? "\(kilobytes)"
        return "\(formatted) k"
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
        if let volumeLabel = VolumeStatusInfo.capacityLabel(for: currentURL) {
            return volumeLabel
        }

        return availableDiskSpace == "—"
            ? "Free space unavailable"
            : "\(availableDiskSpace) free"
    }

    private var volumeCapacityInfo: VolumeStatusInfo.Capacity? {
        VolumeStatusInfo.capacity(for: currentURL)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            tabStripSection
            HStack(spacing: 8) {
                leftInfoSection
                remoteBadgeSection
                filterSection
                Spacer()
                thumbnailSliderSection
                positionIndicator
            }
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.82))
        }
        .frame(height: 53)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.86))
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
                        .foregroundStyle(markedStatusColor)

                    Text(markedStatusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(markedStatusColor)
                }

            } else {

                HStack(spacing: 4) {
                    Image(systemName: volumeCapacityInfo?.systemImage ?? "internaldrive")
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

    private var tabStripSection: some View {
        TabBarView(panelSide: panelSide)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 29)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.78))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.65))
                    .frame(height: 1)
            }
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
