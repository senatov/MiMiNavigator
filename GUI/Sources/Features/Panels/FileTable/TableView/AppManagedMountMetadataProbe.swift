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
        let childCount: Int?
        let partialSize: Int64?
    }

    // MARK: - Probe
    static func partialMetadata(for url: URL, maxDepth: Int = 3, timeoutMs: UInt64 = 1_200) async -> Result? {
        await scanPartial(url, maxDepth: maxDepth, deadline: Date().addingTimeInterval(Double(timeoutMs) / 1_000))
    }

    // MARK: - Partial Scan
    private static func scanPartial(_ url: URL, maxDepth: Int, deadline: Date) async -> Result? {
        let quickCount = directoryEntryCount(url)
        guard let rootChildren = await contentsOfDirectory(url, deadline: deadline) else {
            return quickCount.map { Result(childCount: $0, partialSize: nil) }
        }
        let stats = await accumulatedSize(rootChildren, depth: 1, maxDepth: maxDepth, deadline: deadline)
        let size = usefulPartialSize(stats, rootChildren: rootChildren)
        return Result(childCount: rootChildren.count, partialSize: size)
    }

    // MARK: - Accumulate Size
    private static func accumulatedSize(_ children: [URL], depth: Int, maxDepth: Int, deadline: Date) async -> ScanStats {
        var stats = ScanStats()
        for child in children {
            if Task.isCancelled || Date() >= deadline {
                stats.hitDeadline = true
                break
            }
            guard let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]) else { continue }
            if values.isRegularFile == true {
                stats.total += Int64(values.fileSize ?? 0)
                stats.fileCount += 1
            } else if values.isDirectory == true && depth < maxDepth {
                stats.directoryCount += 1
                guard let branchChildren = await contentsOfDirectory(child, deadline: deadline) else {
                    stats.skippedDirectories += 1
                    continue
                }
                stats.merge(await accumulatedSize(branchChildren, depth: depth + 1, maxDepth: maxDepth, deadline: deadline))
            } else if values.isDirectory == true {
                stats.directoryCount += 1
                stats.skippedDirectories += 1
            }
        }
        return stats
    }

    // MARK: - Timed Directory Listing
    private static func contentsOfDirectory(_ url: URL, deadline: Date) async -> [URL]? {
        let remaining = max(0.05, deadline.timeIntervalSinceNow)
        let timeout = min(0.25, remaining)
        return await withCheckedContinuation { continuation in
            let gate = ResumeGate<[URL]?>(continuation)
            DispatchQueue.global(qos: .utility).async {
                let result = try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
                    options: []
                )
                gate.resume(result)
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                gate.resume(nil)
            }
        }
    }

    // MARK: - Directory Entry Count
    private static func directoryEntryCount(_ url: URL) -> Int? {
        guard let values = try? url.resourceValues(forKeys: [.directoryEntryCountKey]) else { return nil }
        return values.directoryEntryCount
    }

    // MARK: - Size Usefulness
    private static func usefulPartialSize(_ stats: ScanStats, rootChildren: [URL]) -> Int64? {
        if stats.fileCount > 0 { return stats.total }
        if rootChildren.isEmpty { return 0 }
        if stats.skippedDirectories > 0 || stats.hitDeadline || stats.directoryCount > 0 { return nil }
        return stats.total
    }
}

// MARK: - App Managed Mount Scan Stats
private struct ScanStats {
    var total: Int64 = 0
    var fileCount: Int = 0
    var directoryCount: Int = 0
    var skippedDirectories: Int = 0
    var hitDeadline: Bool = false
    mutating func merge(_ other: ScanStats) {
        total += other.total
        fileCount += other.fileCount
        directoryCount += other.directoryCount
        skippedDirectories += other.skippedDirectories
        hitDeadline = hitDeadline || other.hitDeadline
    }
}

// MARK: - Timed Probe Resume Gate
private final class ResumeGate<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<Value, Never>
    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }
    func resume(_ value: Value) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: value)
    }
}
