// DirectorySizeCalculator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Calculates total size and item count of directories

import Foundation

// MARK: - Directory Size Calculator
/// Calculates size and item count for directories
enum DirectorySizeCalculator {
    
    /// Calculate total size and item count of a directory
    static func calculate(at url: URL, fileManager: FileManager = .default) -> (size: Int64, itemCount: Int) {
        var totalSize: Int64 = 0
        var count = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            log.warning("[DirectorySizeCalculator] failed to enumerate: \(url.path)")
            return (0, 0)
        }
        
        for case let fileURL as URL in enumerator {
            count += 1
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                log.warning("[DirectorySizeCalculator] failed to get size: \(fileURL.path)")
            }
        }
        
        log.debug("[DirectorySizeCalculator] \(url.lastPathComponent): \(count) items, \(totalSize) bytes")
        return (totalSize, count)
    }
}
