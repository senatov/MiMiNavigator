// FileContentHashCache.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent SHA-256 cache validated by file size and modification time.

import CacheKit
import CryptoKit
import Foundation

// MARK: - File Content Hash Cache
actor FileContentHashCache {
    static let shared = FileContentHashCache()
    private let namespace: String
    private let store: PersistentCacheStore?
    private var didPrune = false

    private struct HashRecord: Codable {
        let digest: Data
        let size: UInt64
        let modificationTime: TimeInterval
    }

    private struct FileIdentity: Equatable, Sendable {
        let size: UInt64
        let modificationTime: TimeInterval
    }

    init(
        store: PersistentCacheStore? = ApplicationPersistentCache.shared,
        namespace: String = "file-content-sha256-v1"
    ) {
        self.store = store
        self.namespace = namespace
    }

    // MARK: - Compare
    func contentsEqual(_ firstURL: URL, _ secondURL: URL) async -> Bool? {
        guard let firstIdentity = identity(for: firstURL), let secondIdentity = identity(for: secondURL) else { return nil }
        guard firstIdentity.size == secondIdentity.size else { return false }
        async let firstDigest = digest(for: firstURL, identity: firstIdentity)
        async let secondDigest = digest(for: secondURL, identity: secondIdentity)
        guard let first = await firstDigest, let second = await secondDigest else { return nil }
        return first == second
    }

    // MARK: - Digest
    private func digest(for url: URL, identity expectedIdentity: FileIdentity) async -> Data? {
        await pruneIfNeeded()
        let key = url.standardizedFileURL.resolvingSymlinksInPath().path
        if let store,
            let entry = try? await store.entry(namespace: namespace, key: key),
            let record = try? JSONDecoder().decode(HashRecord.self, from: entry.payload),
            record.size == expectedIdentity.size,
            record.modificationTime == expectedIdentity.modificationTime
        {
            log.debug("[FileHash] persistent hit path='\(url.lastPathComponent)' size=\(expectedIdentity.size)")
            return record.digest
        }
        let digest = await Task.detached(priority: .userInitiated) { Self.computeDigest(url) }.value
        guard let digest, identity(for: url) == expectedIdentity else { return nil }
        let record = HashRecord(
            digest: digest,
            size: expectedIdentity.size,
            modificationTime: expectedIdentity.modificationTime
        )
        if let payload = try? JSONEncoder().encode(record) {
            try? await store?
                .set(
                    namespace: namespace,
                    key: key,
                    payload: payload,
                    expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60)
                )
        }
        return digest
    }

    // MARK: - Identity
    private func identity(for url: URL) -> FileIdentity? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
            values.isRegularFile == true,
            let size = values.fileSize,
            let date = values.contentModificationDate
        else { return nil }
        return FileIdentity(size: UInt64(size), modificationTime: date.timeIntervalSince1970)
    }

    // MARK: - Hashing
    nonisolated private static func computeDigest(_ url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
                if Task.isCancelled { return nil }
                hasher.update(data: chunk)
            }
            return Data(hasher.finalize())
        } catch {
            return nil
        }
    }

    // MARK: - Pruning
    private func pruneIfNeeded() async {
        guard !didPrune else { return }
        didPrune = true
        let policy = CachePruningPolicy(
            maximumIdleAge: 30 * 24 * 60 * 60,
            maximumEntryCount: 4_096,
            maximumTotalCost: 8 * 1_024 * 1_024
        )
        if let removed = try? await store?.prune(namespace: namespace, policy: policy), removed > 0 {
            log.info("[FileHash] pruned \(removed) stale persistent hashes")
        }
    }
}
