// FindFilesResultBuffer.swift
// MiMiNavigator
//
// Created by Claude on 01.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Actor-based buffer that accumulates search results off-MainActor
//   and provides batch flushing with adaptive timing.

import Foundation

// MARK: - FindFilesResultBuffer
/// Accumulates FindFilesResult items off-MainActor.
/// The ViewModel drains pending batches periodically to minimize MainActor invalidation.
actor FindFilesResultBuffer {
    private var pending: [FindFilesResult] = []
    private var allResults: [FindFilesResult] = []
    private var lastFlushTime = ContinuousClock.now
    private let batchThreshold: Int = 100
    private let flushInterval: Duration = .milliseconds(200)
    // MARK: - Append
    func append(_ result: FindFilesResult) {
        pending.append(result)
        allResults.append(result)
    }
    // MARK: - Should Flush
    /// Returns true when enough results have accumulated or enough time has passed.
    /// First 20 results flush instantly for responsive UI feedback.
    func shouldFlush() -> Bool {
        if allResults.count <= 20 {
            return !pending.isEmpty
        }
        let now = ContinuousClock.now
        return pending.count >= batchThreshold
            || (now - lastFlushTime) >= flushInterval
    }
    // MARK: - Drain Pending
    /// Returns and clears the pending buffer. Resets flush timer.
    func drainPending() -> [FindFilesResult] {
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        lastFlushTime = ContinuousClock.now
        return batch
    }
    // MARK: - Snapshot
    func snapshot() -> [FindFilesResult] {
        allResults
    }
    // MARK: - Clear
    func clear() {
        pending.removeAll()
        allResults.removeAll()
    }
}
