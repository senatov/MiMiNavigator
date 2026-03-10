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

        let panelSide: PanelSide

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

        /// Number of displayed files
        private var totalFiles: Int {
            appState.displayedFiles(for: panelSide).count
        }

        /// Current path for this panel
        private var currentPath: String {
            panelSide == .left ? appState.leftPath : appState.rightPath
        }

        /// Selected file index (1‑based). 0 if nothing selected.
        /// Cached by AppState → O(1)
        private var selectedIndex: Int {
            appState.selectedIndex(for: panelSide)
        }


        /// Formatted size of marked files
        private var formattedMarkedSize: String {
            ByteCountFormatter.string(fromByteCount: markedSize, countStyle: .file)
        }

        /// Active remote connection (if panel path is remote)
        private var remoteConnection: RemoteConnection? {
            guard AppState.isRemotePath(currentPath) else { return nil }
            return RemoteConnectionManager.shared.activeConnection
        }

        /// Filter binding for the current panel
        private var filterQuery: Binding<String> {
            Binding(
                get: {
                    panelSide == .left
                        ? appState.leftFilterQuery
                        : appState.rightFilterQuery
                },
                set: { newValue in
                    if panelSide == .left {
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

            let url = URL(fileURLWithPath: currentPath)

            if let values = try? url.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
            ]) {

                if let important = values.volumeAvailableCapacityForImportantUsage,
                    important > 0
                {
                    return ByteCountFormatter.string(
                        fromByteCount: important,
                        countStyle: .file
                    )
                }

                if let basic = values.volumeAvailableCapacity,
                    basic > 0
                {
                    return ByteCountFormatter.string(
                        fromByteCount: Int64(basic),
                        countStyle: .file
                    )
                }
            }

            if let attrs = try? FileManager.default.attributesOfFileSystem(
                forPath: currentPath
            ),
                let free = attrs[.systemFreeSize] as? Int64,
                free > 0
            {
                return ByteCountFormatter.string(
                    fromByteCount: free,
                    countStyle: .file
                )
            }

            return "—"
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

        fileprivate var leftInfoSection: some View {

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

                        Text("\(availableDiskSpace) free")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        fileprivate var remoteBadgeSection: some View {

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

        fileprivate var filterSection: some View {

            PanelFilterBar(query: filterQuery, panelSide: panelSide)
                .frame(minWidth: 140, maxWidth: 220)
        }

        fileprivate var thumbnailSliderSection: some View {

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

        fileprivate var positionIndicator: some View {

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

    // MARK: - Jump Button
    extension SelectionStatusBar {

        fileprivate func jumpEdgeButton(
            label: String,
            icon: String,
            help: String,
            action: @escaping () -> Void
        ) -> some View {

            Button(action: action) {

                HStack(spacing: 3) {

                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))

                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color(nsColor: .labelColor).opacity(0.75))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .help(help)
        }
    }

    // MARK: - Jump Notifications
    extension Notification.Name {

        static let jumpToFirst = Notification.Name("MiMi.jumpToFirst")
        static let jumpToLast = Notification.Name("MiMi.jumpToLast")
    }

    // MARK: - Preview
    #Preview {

        VStack {
            SelectionStatusBar(panelSide: .left)
        }
        .frame(width: 500)
        .environment(AppState())
    }
