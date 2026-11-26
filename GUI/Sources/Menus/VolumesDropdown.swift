// VolumesDropdown.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Top-menu dropdown for mounted volumes and cloud-storage directories.

import AppKit
import Combine
import Darwin
import SwiftUI

// MARK: - Volume Location
private struct VolumeLocation: Identifiable {
    enum Kind: Equatable {
        case mounted
        case cloud
        case remote
    }
    let id: String
    let title: String
    let url: URL
    let kind: Kind
    let connectionID: UUID?
    var capacity: VolumeStatusInfo.Capacity? = nil
    var canEject = false
}

// MARK: - Volumes Dropdown
struct VolumesDropdown: View {
    let appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var manager = RemoteConnectionManager.shared
    @State private var locations: [VolumeLocation] = []
    @State private var isPresented = false
    @State private var ejectError: String?

    // MARK: - Body
    var body: some View {
        Button {
            ejectError = nil
            refreshLocations()
            isPresented.toggle()
        } label: {
            TopDropdownLabel(title: "Volumes", systemImage: "externaldrive", tint: .accentColor)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .help("Mounted volumes and cloud storage")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            menuContent
                .padding(8)
                .frame(minWidth: 270)
        }
        .onAppear(perform: refreshLocations)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshLocations() }
        }
        .onChange(of: manager.connections.map(\.id)) { _, _ in
            refreshLocations()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in
            refreshLocations()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            refreshLocations()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didRenameVolumeNotification)) { _ in
            refreshLocations()
        }
    }

    // MARK: - Menu Content
    private var menuContent: some View {
        let mounted = locations.filter { $0.kind == .mounted }
        let cloud = locations.filter { $0.kind == .cloud }
        let remote = locations.filter { $0.kind == .remote }
        return VStack(alignment: .leading, spacing: 5) {
            if locations.isEmpty {
                Text("No volumes available")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
            if !mounted.isEmpty {
                locationSection("Mounted Volumes", locations: mounted, systemImage: "externaldrive.fill")
            }
            if !cloud.isEmpty {
                locationSection("Cloud Storage", locations: cloud, systemImage: "cloud.fill")
            }
            if !remote.isEmpty {
                locationSection("Remote Sessions", locations: remote, systemImage: "network")
            }
            if let ejectError {
                Text(ejectError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Location Section
    private func locationSection(_ title: String, locations: [VolumeLocation], systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            ForEach(locations) { location in
                HStack(spacing: 4) {
                    locationButton(location, systemImage: systemImage)
                    if location.canEject {
                        Button {
                            eject(location)
                        } label: {
                            Image(systemName: "eject")
                        }
                        .accessibilityLabel("Eject \(location.title)")
                        .help("Eject \(location.title)")
                    }
                }
            }
        }
    }

    // MARK: - Location Button
    private func locationButton(_ location: VolumeLocation, systemImage: String) -> some View {
        Button {
            isPresented = false
            navigate(to: location)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: location.capacity?.systemImage ?? systemImage)
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(location.title)
                        .lineLimit(1)
                    if let capacity = location.capacity {
                        Text(capacity.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let used = capacity.usedFraction {
                            ProgressView(value: used)
                                .controlSize(.small)
                                .accessibilityLabel("Disk space used")
                                .accessibilityValue(used.formatted(.percent.precision(.fractionLength(0))))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(location.kind != .remote && !FileManager.default.isReadableFile(atPath: location.url.path))
    }

    // MARK: - Eject Volume
    private func eject(_ location: VolumeLocation) {
        ejectError = nil
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: location.url)
            refreshLocations()
        } catch {
            ejectError = "Could not eject \(location.title). \(error.localizedDescription)"
        }
    }

    // MARK: - Refresh Locations
    private func refreshLocations() {
        locations = Self.scanLocations() + remoteLocations()
    }

    // MARK: - Scan Locations
    private static func scanLocations() -> [VolumeLocation] {
        let fileManager = FileManager.default
        let cloudRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        let iCloudURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        let mounted = mountedVolumes()
        var cloud = directoryChildren(of: cloudRoot, kind: .cloud)
        if isDirectory(iCloudURL) {
            cloud.insert(location(url: iCloudURL, title: "iCloud Drive", kind: .cloud), at: 0)
        }
        return deduplicated(mounted, normalizeCloudTags: false) + deduplicated(cloud, normalizeCloudTags: true)
    }

    // MARK: - Mounted Volumes
    private static func mountedVolumes() -> [VolumeLocation] {
        let keys: [URLResourceKey] = [.volumeLocalizedNameKey, .volumeNameKey, .volumeIsEjectableKey, .volumeIsInternalKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard !AppState.isAppManagedNetworkMountPath(url) else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            let title = values?.volumeLocalizedName ?? values?.volumeName ?? url.lastPathComponent
            guard !title.isEmpty else { return nil }
            var mounted = location(url: url, title: title, kind: .mounted)
            mounted.capacity = VolumeStatusInfo.details(forMountedVolume: url, usePhysicalFreeSpace: true)
            mounted.canEject = url.path.hasPrefix("/Volumes/") && values?.volumeIsEjectable == true && values?.volumeIsInternal != true
            return mounted
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - Directory Children
    private static func directoryChildren(of root: URL, kind: VolumeLocation.Kind) -> [VolumeLocation] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey]
        guard let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        return children.compactMap { url in
            let name = url.lastPathComponent
            guard !name.isEmpty, !name.hasPrefix(".") else { return nil }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            let resolvedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
            guard resolvedPath != "/" else { return nil }
            return location(url: url, title: name, kind: kind)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - Directory Check
    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    // MARK: - Location
    private static func location(url: URL, title: String, kind: VolumeLocation.Kind) -> VolumeLocation {
        VolumeLocation(id: url.absoluteString, title: title, url: url, kind: kind, connectionID: nil)
    }

    // MARK: - Deduplicate Locations
    private static func deduplicated(_ locations: [VolumeLocation], normalizeCloudTags: Bool) -> [VolumeLocation] {
        let grouped = Dictionary(grouping: locations) { location in
            if normalizeCloudTags { return normalizedCloudTag(location.title).lowercased() }
            return location.url.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
        }
        return grouped.values.compactMap { candidates in
            guard let selected = candidates.max(by: { preferredLocation($1, over: $0) }) else { return nil }
            guard normalizeCloudTags else { return selected }
            return location(url: selected.url, title: normalizedCloudTag(selected.title), kind: selected.kind)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - Preferred Location
    private static func preferredLocation(_ candidate: VolumeLocation, over current: VolumeLocation) -> Bool {
        let candidateAccess = accessScore(for: candidate.url)
        let currentAccess = accessScore(for: current.url)
        if candidateAccess != currentAccess { return candidateAccess > currentAccess }
        let candidateDenials = deniedACLCount(for: candidate.url)
        let currentDenials = deniedACLCount(for: current.url)
        if candidateDenials != currentDenials { return candidateDenials < currentDenials }
        return candidate.title.count < current.title.count
    }

    // MARK: - Access Score
    private static func accessScore(for url: URL) -> Int {
        let fileManager = FileManager.default
        let path = url.path
        return [
            fileManager.isReadableFile(atPath: path),
            fileManager.isWritableFile(atPath: path),
            fileManager.isExecutableFile(atPath: path),
            fileManager.isDeletableFile(atPath: path),
        ].filter { $0 }.count
    }

    // MARK: - Denied ACL Count
    private static func deniedACLCount(for url: URL) -> Int {
        guard let acl = acl_get_file(url.path, ACL_TYPE_EXTENDED) else { return 0 }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        guard let text = acl_to_text(acl, nil) else { return 0 }
        defer { acl_free(UnsafeMutableRawPointer(text)) }
        return String(cString: text).components(separatedBy: .newlines).filter { $0.contains(":deny:") }.count
    }

    // MARK: - Normalized Cloud Tag
    private static func normalizedCloudTag(_ title: String) -> String {
        let dateSuffix = #" \(\d{2}\.\d{2}\.\d{2,4}(?: [^)]+)?\)$"#
        guard let range = title.range(of: dateSuffix, options: .regularExpression) else { return title }
        return String(title[..<range.lowerBound])
    }

    // MARK: - Remote Locations
    private func remoteLocations() -> [VolumeLocation] {
        manager.connections.compactMap { connection in
            guard let url = remoteURL(from: connection.provider.mountPath) else { return nil }
            return VolumeLocation(
                id: "remote:\(connection.id)",
                title: connection.displayName,
                url: url,
                kind: .remote,
                connectionID: connection.id
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - Remote URL
    private func remoteURL(from mountPath: String) -> URL? {
        guard !mountPath.isEmpty else { return nil }
        if mountPath.hasPrefix("/") { return URL(fileURLWithPath: mountPath, isDirectory: true) }
        return URL(string: mountPath)
    }

    // MARK: - Navigate
    private func navigate(to location: VolumeLocation) {
        let panel = appState.focusedPanel
        if let connectionID = location.connectionID {
            manager.setActive(id: connectionID)
        }
        Task { @MainActor in
            let path = AppState.isRemotePath(location.url) ? location.url.absoluteString : location.url.path
            await appState.navigateToDirectory(path, on: panel)
            log.info("[VolumesDropdown] navigate panel=\(panel) path='\(path)'")
        }
    }
}
