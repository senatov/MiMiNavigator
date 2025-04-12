//
//  FavoritesScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

/// Scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
class FavoritesScanner {
    private var favPaths = Set<URL>()

    // MARK: - Public Method
    public func scanFavorites() -> [CustomFile] {
        LogMan.log.debug("scanFavorites()")
        favPaths.removeAll()  // Очистка перед новым сканированием
        return FavTreePanel.allDirectories.compactMap {
            buildFileStructure(at: $0, maxDirectories: 0xFF)
        }
    }

    // MARK: - BFS Scanner
    private func buildFileStructure(at rootURL: URL, maxDirectories: Int = 0xFF, maxDepth: Int = 3) -> CustomFile? {
        LogMan.log.debug("buildFileStructure() for \(rootURL.path)")
        guard favPaths.insert(rootURL).inserted else {
            LogMan.log.warning("Skipped duplicate scan of directory: \(rootURL.path)")
            return nil
        }
        var queue: [(url: URL, depth: Int)] = [(rootURL, 0)]
        var fileMap = [URL: CustomFile]()
        var rootFile: CustomFile?
        while !queue.isEmpty {
            let (currentURL, currentDepth) = queue.removeFirst()
            guard let resourceValues = try? currentURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) else {
                LogMan.log.warning("Skipping \(currentURL.path): cannot retrieve resource values.")
                continue
            }
            if resourceValues.isSymbolicLink == true {
                LogMan.log.warning("Skipping symbolic link: \(currentURL.path)")
                continue
            }
            let isDirectory = resourceValues.isDirectory ?? false
            let fileNode = CustomFile(
                name: currentURL.lastPathComponent,
                path: currentURL.path,
                isDirectory: isDirectory,
                children: isDirectory ? [] : nil
            )
            fileMap[currentURL] = fileNode
            if rootFile == nil {
                rootFile = fileNode
            }
            guard isDirectory, currentDepth < maxDepth else { continue }
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: currentURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles]
                )
                for item in contents.prefix(maxDirectories) {
                    if favPaths.contains(item) { continue }
                    favPaths.insert(item)
                    guard let itemResourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey]),
                        let isItemDirectory = itemResourceValues.isDirectory
                    else { continue }
                    queue.append((item, currentDepth + 1))
                    let tempNode = CustomFile(
                        name: item.lastPathComponent,
                        path: item.path,
                        isDirectory: isItemDirectory,
                        children: isItemDirectory ? [] : nil
                    )
                    fileMap[currentURL]?.children?.append(tempNode)
                    fileMap[item] = tempNode
                }

            } catch {
                LogMan.log.error("Failed reading directory: \(currentURL.path), error: \(error.localizedDescription)")
            }
        }
        return rootFile
    }
}
