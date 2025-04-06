//
//  FavoritesScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

/// This class scans commonly used "Favorites" folders on macOS and builds a CustomFile structure
class FavoritesScanner {
    private var visitedPaths = Set<URL>()

    // MARK: - Public Method
    public func scanFavorites() -> [CustomFile] {
        LogMan.log.debug("scanFavorites() started")
        let favoritePaths = USRDrivePanel.allDirectories
        return favoritePaths.compactMap { buildFileStructure(at: $0, maxDirectories: 0xFF) }
    }

    // MARK: - Iterative File Structure Scanner (BFS)
    private func buildFileStructure(at rootURL: URL, maxDirectories: Int = 0xFF, maxDepth: Int = 3) -> CustomFile? {
        //LogMan.log.debug("Scanning: \(rootURL.path)")
        var visitedPaths = Set<URL>()
        visitedPaths.insert(rootURL)
        // Очередь с уровнями (URL, depth)
        var queue: [(url: URL, depth: Int)] = [(rootURL, 0)]
        var fileMap = [URL: CustomFile]()
        var rootFile: CustomFile?

        while !queue.isEmpty {
            let (currentURL, currentDepth) = queue.removeFirst()
            // Прекращаем углубление, если достигнут maxDepth
            if currentDepth >= maxDepth {
                continue
            }
            // Получаем свойства файла/папки
            guard let resourceValues = try? currentURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) else {
                LogMan.log.error("Failed to get resource values for \(currentURL.path)")
                continue
            }
            // Пропускаем символические ссылки
            if resourceValues.isSymbolicLink == true {
                //LogMan.log.debug("Skipping symbolic link: \(currentURL.path)")
                continue
            }
            let isDirectory = resourceValues.isDirectory ?? false
            let fileName = currentURL.lastPathComponent
            let fileNode = CustomFile(name: fileName, path: currentURL.path, isDirectory: isDirectory, children: [])
            fileMap[currentURL] = fileNode
            if rootFile == nil {
                rootFile = fileNode
            }

            // Обрабатываем директории, если глубина позволяет
            if isDirectory {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: currentURL,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )

                    var children: [CustomFile] = []

                    for item in contents.prefix(maxDirectories) {
                        if visitedPaths.contains(item) { continue }
                        visitedPaths.insert(item)

                        // Добавляем в очередь только если не превышен maxDepth
                        if currentDepth + 1 < maxDepth {
                            queue.append((item, currentDepth + 1))
                        }

                        let tempNode = CustomFile(name: item.lastPathComponent, path: item.path, isDirectory: false, children: nil)
                        children.append(tempNode)
                        fileMap[item] = tempNode
                    }

                    // Корректно обновляем узел в fileMap
                    if let updatedNode = fileMap[currentURL] {
                        fileMap[currentURL] = CustomFile(
                            name: updatedNode.name,
                            path: updatedNode.path,
                            isDirectory: updatedNode.isDirectory,
                            children: children
                        )
                    }
                } catch {
                    LogMan.log.error("Failed to read contents of directory: \(currentURL.path) – \(error.localizedDescription)")
                }
            }
        }

        return rootFile
    }
}
