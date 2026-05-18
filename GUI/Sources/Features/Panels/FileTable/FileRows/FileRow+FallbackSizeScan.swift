//
//  FileRow+FallbackSizeScan.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - Fallback Size Scan
extension FileRow {

    // MARK: - Fallback directory scan
    func fallbackDirectoryScanAsync(url: URL) async -> Int64 {
        let target = resolvedDirectorySizeTargetURL(from: url)
        return await Task.detached(priority: .utility) {
            Self.fallbackDirectoryScan(target)
        }.value
    }

    // MARK: - Fallback worker
    private nonisolated static func fallbackDirectoryScan(_ target: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
            .isReadableKey,
        ]
        let enumerator = fm.enumerator(
            at: target,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants, .skipsHiddenFiles],
            errorHandler: { failedURL, error in
                log.warning("[FileRow] Fallback scan skipping inaccessible path '\(failedURL.path)': \(error.localizedDescription)")
                return true
            }
        )
        guard let enumerator else {
            log.warning("[FileRow] Fallback scan could not start for '\(target.path)'")
            return 0
        }
        while let next = enumerator.nextObject() as? URL {
            guard let values = try? next.resourceValues(forKeys: keys) else {
                log.debug("[FileRow] Fallback scan skipping unreadable metadata for '\(next.path)'")
                continue
            }
            if values.isReadable == false {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                log.debug("[FileRow] Fallback scan skipping unreadable path '\(next.path)'")
                continue
            }
            if let alloc = values.totalFileAllocatedSize {
                total += Int64(alloc)
            } else if let alloc = values.fileAllocatedSize {
                total += Int64(alloc)
            } else if let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
