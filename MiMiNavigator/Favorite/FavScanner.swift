//
//  FavoritesScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import FilesProvider
import Foundation
import _Concurrency

// MARK: - This class scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
@MainActor
class FavScanner {

    private var visitedPaths = Set<URL>()
    private let maxDirectories = 64
    private let maxDepth = 2
    private var currentDepth = 0


    // MARK: - Scans favorites, iCloud, OneDrive, network and local volumes
    func scanFavoritesAndNetworkVolumes(completion: @escaping ([CustomFile]) -> Void) {
        visitedPaths.removeAll()
        log.info(#function)
        _ = LocalFileProvider()

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

    // MARK: -
    private func collectFavorites() -> [CustomFile] {
        let favoriteURLs = FileManager.default.allDirectories
        return favoriteURLs.compactMap { buildFavTreeStructure(at: $0) }
    }


    // MARK: -
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


    // MARK: -
    private func collectOneDrive() -> [CustomFile] {
        let cloudStorageURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/CloudStorage")
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: cloudStorageURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { return [] }
        return contents.filter { $0.lastPathComponent.hasPrefix("OneDrive") }
            .compactMap { buildFavTreeStructure(at: $0) }
    }


    // MARK: -
    private func scanVolumesAndComplete(
        favorites: [CustomFile],
        icloud: [CustomFile],
        oneDrive: [CustomFile],
        completion: @escaping ([CustomFile]) -> Void
    ) async {
        var network: [CustomFile] = []
        var localDisks: [CustomFile] = []
        var result: [CustomFile] = []

        guard
            let volumesURL = await resolveVolumesURLOrReturnPartialResult(
                favorites: favorites,
                icloud: icloud,
                oneDrive: oneDrive,
                completion: completion
            )
        else {
            return
        }
        if let contents = try? FileManager.default.contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: nil) {
            for url in contents
            where (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
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
            result.append(CustomFile(name: "Favorites", path: .empty, children: favorites))
        }
        if !icloud.isEmpty {
            result.append(CustomFile(name: "iCloud Drive", path: .empty, children: icloud))
        }
        if !oneDrive.isEmpty {
            result.append(CustomFile(name: "OneDrive", path: .empty, children: oneDrive))
        }
        if !network.isEmpty {
            result.append(CustomFile(name: "Network Volumes", path: .empty, children: network))
        }
        if !localDisks.isEmpty {
            result.append(CustomFile(name: "Local Volumes", path: .empty, children: localDisks))
        }
        log.info("Total groups: \(result.count)")
        completion(result)
        volumesURL.stopAccessingSecurityScopedResource()
    }


    // MARK: - Helpers
    private func scanVolumes(at url: URL) -> (network: [CustomFile], local: [CustomFile]) {
        var networkNodes = [CustomFile]()
        var localNodes = [CustomFile]()
        let contents = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        for item in contents {
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let key = URLResourceKey("volumeIsNetwork")
            let values = try? item.resourceValues(forKeys: [key])
            let isNetwork = (values?.allValues[key] as? Bool) ?? false
            if let node = buildFavTreeStructure(at: item) {
                if isNetwork {
                    networkNodes.append(node)
                } else {
                    localNodes.append(node)
                }
            }
        }
        return (networkNodes, localNodes)
    }

    // MARK: -
    func scanOnlyFavorites() -> [CustomFile] {
        log.info(#function)
        let favoritePaths = FileManager.default.allDirectories
        let trees = favoritePaths.compactMap { buildFavTreeStructure(at: $0) }
        log.info("Total directory branches: \(trees.count)")
        return trees
    }

    
    // MARK: - Iterative File Structure Scanner (BFS)
    private func buildFavTreeStructure(at url: URL) -> CustomFile? {
        log.info(#function)
        currentDepth += 1
        defer { currentDepth -= 1 }
        log.info("buildFavTreeStructure() depth: \(currentDepth) at \(url.path)")
        // Avoid revisiting the same path
        guard !visitedPaths.contains(url) else {
            return nil
        }
        visitedPaths.insert(url)
        guard isValidDirectory(url) else {
            return nil
        }
        // approx. character limit to fit the visual frame
        let maxDisplayWidth: Int = 75
        var fileName = url.lastPathComponent
        if fileName.count > maxDisplayWidth {
            fileName = String(fileName.prefix(maxDisplayWidth - 3)) + "..."
        }

        let children = buildChildren(for: url)
        return CustomFile(name: fileName, path: url.path, children: children)
    }

    // MARK: -
    private func isValidDirectory(_ url: URL) -> Bool {
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .isDirectoryKey, .isHiddenKey, .fileResourceTypeKey]
        let values = try? url.resourceValues(forKeys: Set(keys))
        if values?.isHidden == true { return false }
        if values?.isDirectory == true { return true }
        if values?.isSymbolicLink == true {
            let resolved = url.resolvingSymlinksInPath()
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir) { return isDir.boolValue }
        }
        return false
    }

    // MARK: -
    private func buildChildren(for url: URL) -> [CustomFile]? {
        guard currentDepth <= maxDepth else { return nil }
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey], options: [.skipsHiddenFiles])) ?? []
        return contents.prefix(maxDirectories)
            .filter { item in
                guard let vals = try? item.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey]) else { return false }
                return vals.isDirectory == true && vals.isHidden != true
            }
            .compactMap { buildFavTreeStructure(at: $0) }
    }


    // MARK: - Requests user to select /Volumes and returns the security-scoped URL
    func requestAccessToVolumesDirectory() async -> URL? {
        log.info(#function)
        let openPanel = NSOpenPanel()
        openPanel.title = "Mimi: Please select /Volumes"
        openPanel.allowsConcurrentViewDrawing = true
        openPanel.message = "This is necessary to access mounted system volumes and favorites"
        openPanel.prompt = "Select"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = URL(fileURLWithPath: "/Volumes")

        return await withCheckedContinuation { continuation in
            openPanel.begin { [openPanel] response in
                Task { @MainActor in
                    if response == .OK {
                        let selectedURL = openPanel.url
                        if let url = selectedURL, url.startAccessingSecurityScopedResource() {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    // MARK: -
    private func resolveVolumesURLOrReturnPartialResult(
        favorites: [CustomFile],
        icloud: [CustomFile],
        oneDrive: [CustomFile],
        completion: @escaping ([CustomFile]) -> Void
    ) async -> URL? {
        guard let volumesURL = await requestAccessToVolumesDirectory() else {
            log.error("User did not grant access to /Volumes")
            completion([
                CustomFile(name: "Favorites", path: "", children: favorites),
                CustomFile(name: "iCloud Drive", path: "", children: icloud),
                CustomFile(name: "OneDrive", path: "", children: oneDrive),
            ])
            return nil
        }
        return volumesURL
    }
}

