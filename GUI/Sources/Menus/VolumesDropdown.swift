// VolumesDropdown.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Top-menu dropdown for mounted volumes and cloud-storage directories.

import AppKit
import Combine
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
}

// MARK: - Volumes Dropdown
struct VolumesDropdown: View {
    let appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var manager = RemoteConnectionManager.shared
    @State private var locations: [VolumeLocation] = []

    // MARK: - Body
    var body: some View {
        Menu {
            menuContent
        } label: {
            TopDropdownLabel(title: "Volumes", systemImage: "externaldrive", tint: .accentColor)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.regular)
        .help("Mounted volumes and cloud storage")
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
    }

    // MARK: - Menu Content
    @ViewBuilder
    private var menuContent: some View {
        let mounted = locations.filter { $0.kind == .mounted }
        let cloud = locations.filter { $0.kind == .cloud }
        let remote = locations.filter { $0.kind == .remote }
        if locations.isEmpty {
            Text("No volumes available")
                .foregroundStyle(.secondary)
        } else {
            if !mounted.isEmpty {
                Section("Mounted Volumes") {
                    ForEach(mounted) { location in
                        locationButton(location, systemImage: "externaldrive.fill")
                    }
                }
            }
            if !cloud.isEmpty {
                Section("Cloud Storage") {
                    ForEach(cloud) { location in
                        locationButton(location, systemImage: "cloud.fill")
                    }
                }
            }
            if !remote.isEmpty {
                Section("Remote Sessions") {
                    ForEach(remote) { location in
                        locationButton(location, systemImage: "network")
                    }
                }
            }
        }
    }

    // MARK: - Location Button
    private func locationButton(_ location: VolumeLocation, systemImage: String) -> some View {
        Button {
            navigate(to: location)
        } label: {
            Label(location.title, systemImage: systemImage)
        }
    }

    // MARK: - Refresh Locations
    private func refreshLocations() {
        locations = Self.scanLocations() + remoteLocations()
    }

    // MARK: - Scan Locations
    private static func scanLocations() -> [VolumeLocation] {
        let fileManager = FileManager.default
        let volumesRoot = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        let cloudRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        let iCloudURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        let mounted = directoryChildren(of: volumesRoot, kind: .mounted, excludingSystemDirectories: true)
        var cloud = directoryChildren(of: cloudRoot, kind: .cloud, excludingSystemDirectories: false)
        if isDirectory(iCloudURL) {
            cloud.insert(location(url: iCloudURL, title: "iCloud Drive", kind: .cloud), at: 0)
        }
        return mounted + cloud
    }

    // MARK: - Directory Children
    private static func directoryChildren(of root: URL, kind: VolumeLocation.Kind, excludingSystemDirectories: Bool) -> [VolumeLocation] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey]
        guard let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        return children.compactMap { url in
            let name = url.lastPathComponent
            guard !name.isEmpty, !name.hasPrefix("."), !(excludingSystemDirectories && name.hasPrefix("com.apple.")) else { return nil }
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
