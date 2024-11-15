//
//  FavoritesScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// This class scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
class FavoritesScanner {
    private var visitedPaths = Set<String>()

    public func scanFavorites() -> [CustomFile] {
        log.debug("scanFavorites()")
        let favoritePaths = FileManager.default.allDirectories
        var favorites: [CustomFile] = []
        for path in favoritePaths {
            if let customFile = buildFavoriteStructure(at: path) {
                favorites.append(customFile)
            }
        }
        return favorites
    }

    private func buildFavoriteStructure(at url: URL, maxDirectories: Int = 34) -> CustomFile? {
        log.debug("buildFavoriteStructure()")
        guard !visitedPaths.contains(url.path) else {
            return nil
        }
        visitedPaths.insert(url.path)
        log.debug("buildFileStructure() \(url.path)")
        let fileManager = FileManager.default
        let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard resourceValues?.isSymbolicLink != true else {
            return nil
        }
        let isDirectory = resourceValues?.isDirectory ?? false
        let fileName = url.lastPathComponent
        var children: [CustomFile] = []
        if isDirectory {
            let contents = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            var directoryCount = 0
            for item in contents {
                // Limit to only the first maxDirectories
                if directoryCount >= maxDirectories {
                    log.debug("Reached the maximum directory limit within buildFavoriteStructure, stopping further scanning.")
                    break
                }
                if let child = buildFavoriteStructure(at: item, maxDirectories: 0) { // maxDirectories 0 prevents further recursion
                    children.append(child)
                    directoryCount += 1
                }
            }
        }
        return CustomFile(name: fileName, path: url.path, isDirectory: isDirectory, children: children.isEmpty ? nil : children)
    }

    private func buildFileStructure(at url: URL) -> CustomFile? {
        log.debug("buildFileStructure()")
        guard !visitedPaths.contains(url.path) else {
            return nil
        }
        visitedPaths.insert(url.path)
        log.debug("buildFileStructure() \(url.path)")
        let fileManager = FileManager.default
        let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard resourceValues?.isSymbolicLink != true else {
            return nil
        }

        let isDirectory = resourceValues?.isDirectory ?? false
        let fileName = url.lastPathComponent
        var children: [CustomFile]?

        if isDirectory {
            let contents = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
            children = contents.compactMap { buildFileStructure(at: $0) }
        }
        return CustomFile(name: fileName, path: url.path, isDirectory: isDirectory, children: children)
    }
}
