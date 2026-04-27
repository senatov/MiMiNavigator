// FinderSidebarSources.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import FavoritesKit
import SwiftUI

// MARK: - Finder Sidebar Sources
extension FinderSidebarView {
    // MARK: - Top Items
    var topItems: [FinderSidebarItem] {
        [
            FinderSidebarItem(title: "History", systemImage: "clock.arrow.circlepath", tint: .primary, action: .history),
            FinderSidebarItem(title: "Shared", systemImage: "folder.badge.person.crop", tint: .primary, action: .network)
        ]
    }

    // MARK: - Favorite Items
    var favoriteItems: [FinderSidebarItem] {
        let finderItems = items(fromSystemGroupsMatching: ["favorite"])
        return uniqueItems(finderItems.isEmpty ? standardFavoriteItems : finderItems)
    }

    // MARK: - Location Items
    var locationItems: [FinderSidebarItem] {
        let systemItems = items(fromSystemGroupsMatching: ["location", "device", "server"])
            .filter { $0.identityKey != "icloud-drive" && $0.title != "iCloud Drive" }
        return uniqueItems(
            cloudLocationItems
                + systemItems
                + volumes
                + systemLocationItems
        )
    }

    // MARK: - Standard Favorites
    private var standardFavoriteItems: [FinderSidebarItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        return [
            FinderSidebarItem(title: "Applications", systemImage: "app.badge", action: .navigate(URL(fileURLWithPath: "/Applications", isDirectory: true))),
            FinderSidebarItem(title: "Downloads", systemImage: "arrow.down.circle", tint: .blue, action: .navigate(fm.downloadsDirectory)),
            FinderSidebarItem(title: "Documents", systemImage: "doc", action: .navigate(fm.documentsDirectory)),
            FinderSidebarItem(title: "Desktop", systemImage: "rectangle", action: .navigate(fm.desktopDirectory)),
            FinderSidebarItem(title: "Pictures", systemImage: "photo", action: .navigate(fm.picturesDirectory)),
            FinderSidebarItem(title: "Movies", systemImage: "film", action: .navigate(fm.moviesDirectory)),
            FinderSidebarItem(title: "Music", systemImage: "music.note", action: .navigate(fm.musicDirectory)),
            FinderSidebarItem(title: home.lastPathComponent, systemImage: "house", action: .navigate(home))
        ].filter(\.shouldShow)
    }

    // MARK: - System Locations
    private var systemLocationItems: [FinderSidebarItem] {
        [
            FinderSidebarItem(title: "AirDrop", systemImage: "antenna.radiowaves.left.and.right", action: .airDrop),
            FinderSidebarItem(title: "Network", systemImage: "globe", action: .network),
            FinderSidebarItem(title: "Trash", systemImage: "trash", action: .navigate(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)))
        ]
    }

    // MARK: - Cloud Locations
    private var cloudLocationItems: [FinderSidebarItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        let cloudStorage = home.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        var items = [FinderSidebarItem(title: "iCloud Drive", systemImage: "icloud", action: .navigate(cloudDocs))]
        if let children = try? FileManager.default.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            items += children.compactMap(cloudStorageItem)
        }
        return items.filter(\.shouldShow)
    }

    // MARK: - System Favorite Items
    func items(fromSystemGroupsMatching tokens: [String]) -> [FinderSidebarItem] {
        favoritesStore.systemFavorites
            .filter { group in
                let name = group.name.lowercased()
                return tokens.contains { name.contains($0) }
            }
            .flatMap { $0.children ?? [] }
            .compactMap(sidebarItem)
    }

    // MARK: - Sidebar Item
    func sidebarItem(from item: FavoriteItem) -> FinderSidebarItem? {
        if item.url.isFileURL, !FileManager.default.fileExists(atPath: item.url.path) {
            return nil
        }
        let icon = item.iconDescriptor()
        return FinderSidebarItem(title: item.name, systemImage: icon.systemName, tint: tint(for: item, descriptor: icon), action: .navigate(item.url))
    }

    // MARK: - Tint
    func tint(for item: FavoriteItem, descriptor: FavoriteIconDescriptor) -> Color {
        let path = item.url.path.lowercased()
        if item.url.scheme?.lowercased() != "file" { return .blue }
        if path.contains("clouddocs") || path.contains("cloudstorage") { return .primary }
        if descriptor.prefersLargeMutedStyle { return .secondary }
        return .primary
    }

    // MARK: - Volume Item
    func volumeItem(for url: URL) -> FinderSidebarItem? {
        guard url.isFileURL else { return nil }
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey]
        let values = try? url.resourceValues(forKeys: keys)
        let name = values?.volumeName ?? url.lastPathComponent
        guard !name.isEmpty else { return nil }
        let canUnmount = volumeCanUnmount(values: values, url: url)
        let icon = volumeIcon(values: values, canUnmount: canUnmount)
        return FinderSidebarItem(title: name, systemImage: icon, tint: canUnmount ? .blue : .secondary, action: .navigate(url), canUnmount: canUnmount)
    }

    // MARK: - Volume Can Unmount
    func volumeCanUnmount(values: URLResourceValues?, url: URL) -> Bool {
        guard url.path.hasPrefix("/Volumes/") else { return false }
        if values?.volumeIsInternal == true { return false }
        return values?.volumeIsEjectable == true || values?.volumeIsRemovable == true || url.pathComponents.count > 2
    }

    // MARK: - Volume Icon
    func volumeIcon(values: URLResourceValues?, canUnmount: Bool) -> String {
        if canUnmount { return "externaldrive.fill" }
        if values?.volumeIsInternal == true { return "internaldrive" }
        return "externaldrive"
    }

    // MARK: - Cloud Storage Item
    func cloudStorageItem(for url: URL) -> FinderSidebarItem? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
        return FinderSidebarItem(title: displayName(forCloudStorage: url), systemImage: cloudIcon(for: url), action: .navigate(url))
    }

    // MARK: - Cloud Display Name
    func displayName(forCloudStorage url: URL) -> String {
        let name = url.lastPathComponent
        if name.contains("GoogleDrive") { return "Google Drive" }
        if name.contains("OneDrive") { return "OneDrive" }
        if name.contains("Proton") { return "Proton Drive" }
        return name.replacingOccurrences(of: "-", with: " ")
    }

    // MARK: - Cloud Icon
    func cloudIcon(for url: URL) -> String {
        let name = url.lastPathComponent.lowercased()
        if name.contains("google") { return "triangle" }
        if name.contains("onedrive") { return "cloud" }
        return "folder"
    }

    // MARK: - Unique Items
    func uniqueItems(_ items: [FinderSidebarItem]) -> [FinderSidebarItem] {
        var seen = Set<String>()
        return items.filter { item in
            seen.insert(item.identityKey).inserted
        }
    }
}
