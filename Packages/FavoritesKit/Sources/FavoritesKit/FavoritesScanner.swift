//
// FavoritesScanner.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import Foundation

// MARK: - Scanner for Favorite Directories
/// Scans macOS favorites, iCloud, OneDrive, and volumes
@MainActor
public final class FavoritesScanner {
    
    // MARK: - Configuration
    private enum Config {
        static let maxDirectories = 64
        static let maxDepth = 2
        static let maxDisplayWidth = 75
    }
    
    private var visitedPaths = Set<URL>()
    private var currentDepth = 0
    
    public init() {}
    
    // MARK: - Public API
    
    /// Scans only user favorites (synchronous)
    public func scanFavorites() -> [FavoriteItem] {
        visitedPaths.removeAll()
        let favoritePaths = FileManager.default.allDirectories
        return favoritePaths.compactMap { buildTree(at: $0) }
    }
    
    /// Scans favorites, iCloud, OneDrive, and volumes (async)
    public func scanFavoritesAndVolumes() async -> [FavoriteItem] {
        visitedPaths.removeAll()
        
        let favorites = collectFavorites()
        let icloud = collectICloud()
        let oneDrive = collectOneDrive()
        let (network, localDisks) = await collectVolumes()
        
        var result: [FavoriteItem] = []
        
        if !favorites.isEmpty {
            result.append(.group(name: "Favorites", children: favorites))
        }
        if !icloud.isEmpty {
            result.append(.group(name: "iCloud Drive", children: icloud))
        }
        if !oneDrive.isEmpty {
            result.append(.group(name: "OneDrive", children: oneDrive))
        }
        if !network.isEmpty {
            result.append(.group(name: "Network Volumes", children: network))
        }
        if !localDisks.isEmpty {
            result.append(.group(name: "Local Volumes", children: localDisks))
        }
        
        return result
    }
    
    // MARK: - Private Collection Methods
    
    private func collectFavorites() -> [FavoriteItem] {
        let favoriteURLs = FileManager.default.allDirectories
        return favoriteURLs.compactMap { buildTree(at: $0) }
    }
    
    private func collectICloud() -> [FavoriteItem] {
        let icloudURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        guard FileManager.default.fileExists(atPath: icloudURL.path),
              let node = buildTree(at: icloudURL)
        else {
            return []
        }
        return [node]
    }
    
    private func collectOneDrive() -> [FavoriteItem] {
        let cloudStorageURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/CloudStorage")
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cloudStorageURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents
            .filter { $0.lastPathComponent.hasPrefix("OneDrive") }
            .compactMap { buildTree(at: $0) }
    }
    
    private func collectVolumes() async -> (network: [FavoriteItem], local: [FavoriteItem]) {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        
        // Check access
        if await FavoritesBookmarkStore.shared.hasAccess(to: volumesURL) == false {
            let granted = await FavoritesBookmarkStore.shared.requestAccessPersisting(for: volumesURL, anchorWindow: nil)
            if !granted {
                return ([], [])
            }
        }
        
        var network: [FavoriteItem] = []
        var local: [FavoriteItem] = []
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: nil
        ) else {
            return ([], [])
        }
        
        for url in contents {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            
            let key = URLResourceKey("volumeIsNetwork")
            let values = try? url.resourceValues(forKeys: [key])
            let isNetwork = (values?.allValues[key] as? Bool) ?? false
            
            if let node = buildTree(at: url) {
                if isNetwork {
                    network.append(node)
                } else {
                    local.append(node)
                }
            }
        }
        
        return (network, local)
    }
    
    // MARK: - Tree Building
    
    private func buildTree(at url: URL) -> FavoriteItem? {
        currentDepth += 1
        defer { currentDepth -= 1 }
        
        guard !visitedPaths.contains(url) else { return nil }
        visitedPaths.insert(url)
        
        guard isValidDirectory(url) else { return nil }
        
        var fileName = url.lastPathComponent
        if fileName.count > Config.maxDisplayWidth {
            fileName = String(fileName.prefix(Config.maxDisplayWidth - 3)) + "..."
        }
        
        let children = buildChildren(for: url)
        
        return FavoriteItem(
            name: fileName,
            path: url.path,
            isDirectory: true,
            children: children
        )
    }
    
    private func isValidDirectory(_ url: URL) -> Bool {
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isDirectoryKey, .isHiddenKey]
        let values = try? url.resourceValues(forKeys: Set(keys))
        
        if values?.isHidden == true { return false }
        if values?.isDirectory == true { return true }
        
        if values?.isSymbolicLink == true {
            let resolved = url.resolvingSymlinksInPath()
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir) {
                return isDir.boolValue
            }
        }
        return false
    }
    
    private func buildChildren(for url: URL) -> [FavoriteItem]? {
        guard currentDepth <= Config.maxDepth else { return nil }
        
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        
        return contents.prefix(Config.maxDirectories)
            .filter { item in
                guard let vals = try? item.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey]) else {
                    return false
                }
                return vals.isDirectory == true && vals.isHidden != true
            }
            .compactMap { buildTree(at: $0) }
    }
}

// MARK: - FileManager Extension
extension FileManager {
    /// Returns user's favorite directories from Finder sidebar
    var allDirectories: [URL] {
        var directories: [URL] = []
        
        // Standard user directories
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let standardPaths = ["Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures"]
        
        for path in standardPaths {
            let url = home.appendingPathComponent(path)
            if fileExists(atPath: url.path) {
                directories.append(url)
            }
        }
        
        // Applications
        let apps = URL(fileURLWithPath: "/Applications")
        if fileExists(atPath: apps.path) {
            directories.append(apps)
        }
        
        return directories
    }
}
