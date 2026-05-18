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
    static func partialMetadata(for url: URL, maxDepth: Int = 3, timeoutMs: UInt64 = 1_200) async -> Result? {
        await withTaskGroup(of: Result?.self) { group in
            group.addTask(priority: .utility) {
                await Self.scanPartial(url, maxDepth: maxDepth, deadline: Date().addingTimeInterval(Double(timeoutMs) / 1_000))
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

    // MARK: - Partial Scan
    private static func scanPartial(_ url: URL, maxDepth: Int, deadline: Date) async -> Result? {
        guard let rootChildren = await contentsOfDirectory(url, deadline: deadline) else { return nil }
        let childCount = rootChildren.count
        let shallowSize = await accumulatedSize(rootChildren, depth: 1, maxDepth: maxDepth, deadline: deadline)
        return Result(childCount: childCount, shallowSize: shallowSize)
    }

    // MARK: - Accumulate Size
    private static func accumulatedSize(_ children: [URL], depth: Int, maxDepth: Int, deadline: Date) async -> Int64 {
        var total: Int64 = 0
        for child in children {
            if Task.isCancelled || Date() >= deadline { break }
            guard let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]) else { continue }
            if values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            } else if values.isDirectory == true && depth < maxDepth {
                guard let branchChildren = await contentsOfDirectory(child, deadline: deadline) else { continue }
                total += await accumulatedSize(branchChildren, depth: depth + 1, maxDepth: maxDepth, deadline: deadline)
            }
        }
        return total
    }

    // MARK: - Timed Directory Listing
    private static func contentsOfDirectory(_ url: URL, deadline: Date) async -> [URL]? {
        let remaining = max(0.05, deadline.timeIntervalSinceNow)
        let branchTimeoutMs = UInt64(min(250, remaining * 1_000))
        return await withTaskGroup(of: [URL]?.self) { group in
            group.addTask(priority: .utility) {
                try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
                    options: []
                )
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: branchTimeoutMs * 1_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
