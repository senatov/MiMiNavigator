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
    }
    let url: URL
    let kind: Kind
    var id: String { url.path }
    var title: String { url.lastPathComponent }
}

// MARK: - Volumes Dropdown
struct VolumesDropdown: View {
    let appState: AppState
    @Environment(\.scenePhase) private var scenePhase
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
        }
    }

    // MARK: - Location Button
    private func locationButton(_ location: VolumeLocation, systemImage: String) -> some View {
        Button {
            navigate(to: location.url)
        } label: {
            Label(location.title, systemImage: systemImage)
        }
    }

    // MARK: - Refresh Locations
    private func refreshLocations() {
        locations = Self.scanLocations()
    }

    // MARK: - Scan Locations
    private static func scanLocations() -> [VolumeLocation] {
        let fileManager = FileManager.default
        let volumesRoot = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        let cloudRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        let mounted = directoryChildren(of: volumesRoot, kind: .mounted, excludingSystemDirectories: true)
        let cloud = directoryChildren(of: cloudRoot, kind: .cloud, excludingSystemDirectories: false)
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
            return VolumeLocation(url: url, kind: kind)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - Navigate
    private func navigate(to url: URL) {
        let panel = appState.focusedPanel
        Task { @MainActor in
            await appState.navigateToDirectory(url.path, on: panel)
            log.info("[VolumesDropdown] navigate panel=\(panel) path='\(url.path)'")
        }
    }
}
