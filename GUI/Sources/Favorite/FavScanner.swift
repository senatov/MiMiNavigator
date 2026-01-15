// FavScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import Foundation

// MARK: - Scanner for commonly used "Favorites" folders on macOS
@MainActor
final class FavScanner {
    
    // MARK: - Configuration
    private enum Config {
        static let maxDirectories = 64
        static let maxDepth = 2
        static let maxDisplayWidth = 75
    }
    
    private var visitedPaths = Set<URL>()
    private var currentDepth = 0

    // MARK: - Scans favorites, iCloud, OneDrive, network and local volumes
    func scanFavoritesAndNetworkVolumes(completion: @escaping ([CustomFile]) -> Void) {
        visitedPaths.removeAll()
        log.debug(#function)
        let favorites = collectFavorites()
        let icloud = collectICloud()
        let oneDrive = collectOneDrive()

        Task {
            await scanVolumesAndComplete(
                favorites: favorites,
                icloud: icloud,
                oneDrive: oneDrive,
                completion: completion
            )
        }
    }

    // MARK: - Collect user favorites
    private func collectFavorites() -> [CustomFile] {
        let favoriteURLs = FileManager.default.allDirectories
        return favoriteURLs.compactMap { buildFavTreeStructure(at: $0) }
    }

    // MARK: - Collect iCloud Drive
    private func collectICloud() -> [CustomFile] {
        let icloudURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        guard FileManager.default.fileExists(atPath: icloudURL.path),
              let node = buildFavTreeStructure(at: icloudURL)
        else {
            return []
        }
        return [node]
    }

    // MARK: - Collect OneDrive folders
    private func collectOneDrive() -> [CustomFile] {
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
            .compactMap { buildFavTreeStructure(at: $0) }
    }

    // MARK: - Scan volumes and complete
    private func scanVolumesAndComplete(
        favorites: [CustomFile],
        icloud: [CustomFile],
        oneDrive: [CustomFile],
        completion: @escaping ([CustomFile]) -> Void
    ) async {
        var network: [CustomFile] = []
        var localDisks: [CustomFile] = []
        var result: [CustomFile] = []
        
        guard let volumesURL = await resolveVolumesURLOrReturnPartialResult(
            favorites: favorites,
            icloud: icloud,
            oneDrive: oneDrive,
            completion: completion
        ) else {
            return
        }
        
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: nil
        ) {
            for url in contents where (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                
                let key = URLResourceKey("volumeIsNetwork")
                let values = try? url.resourceValues(forKeys: [key])
                let isNetwork = (values?.allValues[key] as? Bool) ?? false
                
                if let node = buildFavTreeStructure(at: url) {
                    if isNetwork {
                        network.append(node)
                    } else {
                        localDisks.append(node)
                    }
                }
            }
        } else {
            log.error("Cannot read /Volumes contents even after user granted access.")
        }
        
        if !favorites.isEmpty {
            result.append(CustomFile(name: "Favorites", path: "", children: favorites))
        }
        if !icloud.isEmpty {
            result.append(CustomFile(name: "iCloud Drive", path: "", children: icloud))
        }
        if !oneDrive.isEmpty {
            result.append(CustomFile(name: "OneDrive", path: "", children: oneDrive))
        }
        if !network.isEmpty {
            result.append(CustomFile(name: "Network Volumes", path: "", children: network))
        }
        if !localDisks.isEmpty {
            result.append(CustomFile(name: "Local Volumes", path: "", children: localDisks))
        }
        
        log.debug("Total groups: \(result.count)")
        completion(result)
    }

    // MARK: - Scan only favorites
    func scanOnlyFavorites() -> [CustomFile] {
        log.debug(#function + " at maxDepth: \(Config.maxDepth)")
        let favoritePaths = FileManager.default.allDirectories
        let trees = favoritePaths.compactMap { buildFavTreeStructure(at: $0) }
        log.debug("Total directory branches: \(trees.count)")
        return trees
    }

    // MARK: - Build tree structure for a directory
    private func buildFavTreeStructure(at url: URL) -> CustomFile? {
        currentDepth += 1
        defer { currentDepth -= 1 }
        
        // Avoid revisiting the same path
        guard !visitedPaths.contains(url) else { return nil }
        visitedPaths.insert(url)
        
        guard isValidDirectory(url) else { return nil }
        
        // Truncate long names for display
        var fileName = url.lastPathComponent
        if fileName.count > Config.maxDisplayWidth {
            fileName = String(fileName.prefix(Config.maxDisplayWidth - 3)) + "..."
        }

        let children = buildChildren(for: url)
        return CustomFile(name: fileName, path: url.path, children: children)
    }

    // MARK: - Check if URL is a valid directory
    private func isValidDirectory(_ url: URL) -> Bool {
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isDirectoryKey, .isHiddenKey, .fileResourceTypeKey]
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

    // MARK: - Build children for a directory
    private func buildChildren(for url: URL) -> [CustomFile]? {
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
            .compactMap { buildFavTreeStructure(at: $0) }
    }

    // MARK: - Resolve volumes URL or return partial result
    private func resolveVolumesURLOrReturnPartialResult(
        favorites: [CustomFile],
        icloud: [CustomFile],
        oneDrive: [CustomFile],
        completion: @escaping ([CustomFile]) -> Void
    ) async -> URL? {
        let volumesURL = URL(fileURLWithPath: "/Volumes")

        if await BookmarkStore.shared.hasAccess(to: volumesURL) == false {
            let granted = await BookmarkStore.shared.requestAccessPersisting(for: volumesURL)
            if granted == false {
                log.error("User did not grant access to /Volumes")
                completion([
                    CustomFile(name: "Favorites", path: "", children: favorites),
                    CustomFile(name: "iCloud Drive", path: "", children: icloud),
                    CustomFile(name: "OneDrive", path: "", children: oneDrive),
                ])
                return nil
            }
        }
        return volumesURL
    }
}
