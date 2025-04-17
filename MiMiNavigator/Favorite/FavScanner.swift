//
//  FavoritesScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

/// This class scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
class FavScanner {

    // Limits for the breadth and depth of directory scanning
    private let maxDirectories: Int = 0x7D
    // Limits for the breadth and depth of directory scanning
    private let maxDepth: Int = 3

    // MARK: - Entry Point: Scans favorite directories and builds their file trees
    func scanFavorites() -> [CustomFile] {
        log.debug("scanFavorites() started")
        let favoritePaths = FileManager.default.allDirectories
        let trees = favoritePaths.compactMap { buildFavTreeStructure(at: $0) }
        log.debug("Total directory branches across all favorite trees: \(trees.count)")
        return trees
    }

    // MARK: - Iterative File Structure Scanner (BFS)
    private func buildFavTreeStructure(at rootURL: URL) -> CustomFile? {
        // Initialize a set to track visited paths to avoid cycles
        var visitedPaths = Set<URL>()
        visitedPaths.insert(rootURL)

        // Queue to hold URLs and their corresponding depth for BFS
        var queue: [(url: URL, depth: Int)] = [(rootURL, 0)]
        var fileMap = [URL: CustomFile]()
        var rootFile: CustomFile?

        // Process the queue until it's empty
        while !queue.isEmpty {
            let (currentURL, currentDepth) = queue.removeFirst()

            // Stop going deeper if maxDepth is reached
            if currentDepth >= maxDepth {
                continue
            }

            // Get file/folder attributes
            guard let resourceValues = try? currentURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) else {
                log.error("Failed to get resource values for \(currentURL.path)")
                continue
            }

            // Skip symbolic links
            if resourceValues.isSymbolicLink == true {
                continue
            }

            let isDirectory = resourceValues.isDirectory ?? false
            let fileName = currentURL.lastPathComponent
            let fileNode = CustomFile(name: fileName, path: currentURL.path, isDirectory: isDirectory, children: [])
            fileMap[currentURL] = fileNode

            // Set the root file if not already set
            if rootFile == nil {
                rootFile = fileNode
            }

            // Process directories if depth allows
            if isDirectory {
                do {
                    // Get the contents of the directory
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: currentURL,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    var children: [CustomFile] = []

                    // Iterate through the contents, limited by maxDirectories
                    for item in contents.prefix(maxDirectories) {
                        if visitedPaths.contains(item) { continue }
                        visitedPaths.insert(item)

                        // Add to queue only if maxDepth is not exceeded
                        if currentDepth + 1 < maxDepth {
                            queue.append((item, currentDepth + 1))
                        }

                        let itemIsDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                        let tempNode = CustomFile(
                            name: item.lastPathComponent,
                            path: item.path,
                            isDirectory: itemIsDirectory,
                            children: itemIsDirectory ? [] : nil
                        )
                        children.append(tempNode)
                        fileMap[item] = tempNode
                    }

                    // Properly update the node in fileMap with its children
                    if let updatedNode = fileMap[currentURL] {
                        fileMap[currentURL] = CustomFile(
                            name: updatedNode.name,
                            path: updatedNode.path,
                            isDirectory: updatedNode.isDirectory,
                            children: children
                        )
                    }
                } catch {
                    log.error("Failed to read contents of directory: \(currentURL.path) – \(error.localizedDescription)")
                }
            }
        }
        return rootFile
    }

}
