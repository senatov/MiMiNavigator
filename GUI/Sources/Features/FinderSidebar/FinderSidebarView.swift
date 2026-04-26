// FinderSidebarView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Finder-style source list embedded in the main dual-panel window.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Finder Sidebar View
struct FinderSidebarView: View {
    let appState: AppState
    @State private var volumes: [FinderSidebarItem] = []
    @State private var selectedID: String?

    private enum Layout {
        static let rowHeight: CGFloat = 26
        static let iconWidth: CGFloat = 18
        static let horizontalPadding: CGFloat = 10
        static let sectionSpacing: CGFloat = 10
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                section(title: "Favorites", items: favoriteItems)
                section(title: "iCloud", items: iCloudItems)
                section(title: "Locations", items: locationItems)
                tagsSection
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Divider()
        }
        .onAppear(perform: refreshVolumes)
    }

    // MARK: - Favorites
    private var favoriteItems: [FinderSidebarItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            FinderSidebarItem(title: "AirDrop", systemImage: "antenna.radiowaves.left.and.right", action: .airDrop),
            FinderSidebarItem(title: "Photos Library", systemImage: "photo.on.rectangle", action: .openIfExists(home.appendingPathComponent("Pictures/Photos Library.photoslibrary"))),
            FinderSidebarItem(title: "Documents", systemImage: "folder.fill", action: .navigate(home.appendingPathComponent("Documents", isDirectory: true))),
            FinderSidebarItem(title: "Applications", systemImage: "folder.fill", action: .navigate(URL(fileURLWithPath: "/Applications", isDirectory: true))),
            FinderSidebarItem(title: "Desktop", systemImage: "folder.fill", action: .navigate(home.appendingPathComponent("Desktop", isDirectory: true))),
            FinderSidebarItem(title: "Downloads", systemImage: "folder.fill", action: .navigate(home.appendingPathComponent("Downloads", isDirectory: true))),
            FinderSidebarItem(title: "Movies", systemImage: "folder.fill", action: .navigate(home.appendingPathComponent("Movies", isDirectory: true))),
            FinderSidebarItem(title: "Music", systemImage: "folder.fill", action: .navigate(home.appendingPathComponent("Music", isDirectory: true))),
            FinderSidebarItem(title: "Pictures", systemImage: "folder.fill", action: .navigate(home.appendingPathComponent("Pictures", isDirectory: true)))
        ].filter(\.shouldShow)
    }

    // MARK: - iCloud
    private var iCloudItems: [FinderSidebarItem] {
        let cloudDocs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return [
            FinderSidebarItem(title: "iCloud Drive", systemImage: "icloud", action: .navigate(cloudDocs))
        ].filter(\.shouldShow)
    }

    // MARK: - Locations
    private var locationItems: [FinderSidebarItem] {
        volumes + [
            FinderSidebarItem(title: "Network", systemImage: "globe", action: .network)
        ]
    }

    // MARK: - Tags
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("Tags")
            ForEach(FinderSidebarTag.standard) { tag in
                HStack(spacing: 8) {
                    Circle()
                        .fill(tag.color)
                        .frame(width: 12, height: 12)
                    Text(tag.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(height: Layout.rowHeight)
                .padding(.horizontal, Layout.horizontalPadding)
            }
        }
    }

    // MARK: - Section
    private func section(title: String, items: [FinderSidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader(title)
            ForEach(items) { item in
                Button {
                    handle(item)
                } label: {
                    row(item)
                }
                .buttonStyle(.plain)
                .help(item.helpText)
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, 2)
    }

    // MARK: - Row
    private func row(_ item: FinderSidebarItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.system(size: 14))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.tint)
                .frame(width: Layout.iconWidth, height: Layout.iconWidth)
            Text(item.title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .frame(height: Layout.rowHeight)
        .padding(.horizontal, Layout.horizontalPadding)
        .background(selectionBackground(for: item))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Selection Background
    private func selectionBackground(for item: FinderSidebarItem) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isSelected(item) ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    // MARK: - Selection
    private func isSelected(_ item: FinderSidebarItem) -> Bool {
        guard selectedID == item.id else { return false }
        return true
    }

    // MARK: - Handle Item
    private func handle(_ item: FinderSidebarItem) {
        selectedID = item.id
        switch item.action {
        case .airDrop:
            openAirDrop()
        case .network:
            NetworkNeighborhoodCoordinator.shared.toggle()
        case .navigate(let url):
            navigate(to: url)
        case .openIfExists(let url):
            openIfExists(url)
        }
    }

    // MARK: - Navigate
    private func navigate(to url: URL) {
        Task { @MainActor in
            let panel = appState.focusedPanel
            appState.updatePath(url, for: panel)
            await appState.scanner.clearCooldown(for: panel)
            await appState.scanner.refreshFiles(currSide: panel, force: true)
            log.info("[FinderSidebar] navigate panel=\(panel) path='\(url.path)'")
        }
    }

    // MARK: - Open If Exists
    private func openIfExists(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return }
        if isDirectory.boolValue {
            navigate(to: url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Open AirDrop
    private func openAirDrop() {
        guard let url = URL(string: "airdrop://") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Refresh Volumes
    private func refreshVolumes() {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey], options: [.skipHiddenVolumes]) ?? []
        volumes = urls.compactMap(volumeItem)
    }

    // MARK: - Volume Item
    private func volumeItem(for url: URL) -> FinderSidebarItem? {
        guard url.isFileURL else { return nil }
        let name = (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.lastPathComponent
        guard !name.isEmpty else { return nil }
        return FinderSidebarItem(title: name, systemImage: "externaldrive.fill", tint: .secondary, action: .navigate(url))
    }
}

// MARK: - Finder Sidebar Item
private struct FinderSidebarItem: Identifiable {
    let title: String
    let systemImage: String
    let tint: Color
    let action: FinderSidebarAction

    var id: String {
        "\(title)-\(helpText)"
    }

    var helpText: String {
        switch action {
        case .airDrop:
            return "AirDrop"
        case .network:
            return "Network"
        case .navigate(let url), .openIfExists(let url):
            return url.path
        }
    }

    var shouldShow: Bool {
        switch action {
        case .airDrop, .network:
            return true
        case .navigate(let url), .openIfExists(let url):
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    init(title: String, systemImage: String, tint: Color = .blue, action: FinderSidebarAction) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }
}

// MARK: - Finder Sidebar Action
private enum FinderSidebarAction {
    case airDrop
    case network
    case navigate(URL)
    case openIfExists(URL)
}

// MARK: - Finder Sidebar Tag
private struct FinderSidebarTag: Identifiable {
    let title: String
    let color: Color

    var id: String { title }

    static let standard: [FinderSidebarTag] = [
        FinderSidebarTag(title: "Red", color: .red),
        FinderSidebarTag(title: "Orange", color: .orange),
        FinderSidebarTag(title: "Yellow", color: .yellow),
        FinderSidebarTag(title: "Green", color: .green),
        FinderSidebarTag(title: "Blue", color: .blue),
        FinderSidebarTag(title: "Purple", color: .purple),
        FinderSidebarTag(title: "Gray", color: .gray)
    ]
}
