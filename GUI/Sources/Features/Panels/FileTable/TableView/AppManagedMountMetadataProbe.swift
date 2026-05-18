//
//  AppManagedMountMetadataProbe.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - App Managed Mount Metadata Probe
enum AppManagedMountMetadataProbe {

    // MARK: - Result
    struct Result: Sendable {
        let childCount: Int
        let shallowSize: Int64
    }

    // MARK: - Probe
    static func oneLevelMetadata(for url: URL, timeoutMs: UInt64 = 450) async -> Result? {
        await withTaskGroup(of: Result?.self) { group in
            group.addTask(priority: .utility) {
                Self.scanOneLevel(url)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutMs * 1_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - One Level Scan
    private static func scanOneLevel(_ url: URL) -> Result? {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else {
            return nil
        }
        var shallowSize: Int64 = 0
        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys) else { continue }
            guard values.isRegularFile == true else { continue }
            shallowSize += Int64(values.fileSize ?? 0)
        }
        return Result(childCount: children.count, shallowSize: shallowSize)
    }
}
