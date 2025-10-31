//
//  FileScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
import Combine
import Foundation

enum FileScanner {
    // MARK: -
    static func scan(url: URL) throws -> [CustomFile] {
        log.info("scan(url:) \(url.path)")
        var regularDirCount = 0
        var symlinkDirCount = 0
        var fileCount = 0
        var result: [CustomFile] = []
        let fileManager = FileManager.default

        // Ask for both directory and symlink flags so we can distinguish symlinked folders from regular files.
        let wantedKeys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: wantedKeys,
            options: [.skipsHiddenFiles]
        )
        for fileURL in contents {
            // Read resource values once per URL for performance and clarity.
            let values = try? fileURL.resourceValues(forKeys: Set(wantedKeys))
            let isDir = values?.isDirectory ?? false
            let isSymlink = values?.isSymbolicLink ?? false

            // Stats just for insight during development; harmless in production logs.
            if isDir {
                if isSymlink {
                    symlinkDirCount += 1
                } else {
                    regularDirCount += 1
                }
            } else {
                fileCount += 1
            }

            // NOTE: We keep the existing initializer to avoid breaking other code.
            // If CustomFile exposes properties like `isDirectory` / `isSymbolicDirectory`,
            // they should be set inside that type based on the provided path, or consider
            // adding a convenience initializer that accepts these flags.
            let customFile = CustomFile(name: fileURL.lastPathComponent, path: fileURL.path)
            result.append(customFile)
        }
        log.info("scan stats: dirs=\(regularDirCount), symlinkDirs=\(symlinkDirCount), files=\(fileCount)")
        return result
    }
}
