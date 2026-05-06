// DirectorySizeCancellationState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Thread-safe cancellation flag for directory size scans.

import Foundation

// MARK: - Directory Size Cancellation State
final class DirectorySizeCancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    // MARK: - Is Cancelled
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    // MARK: - Cancel
    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
