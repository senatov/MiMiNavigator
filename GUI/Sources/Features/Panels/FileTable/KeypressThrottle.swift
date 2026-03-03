// KeypressThrottle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 03.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Simple throttle for keyboard navigation to prevent UI freeze on rapid keypresses

import Foundation

/// Thread-safe throttle for keyboard events.
/// Returns true only if enough time has passed since the last allowed event.
final class KeypressThrottle: @unchecked Sendable {
    private let interval: TimeInterval
    private var lastTime: Date = .distantPast
    private let lock = NSLock()
    
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    /// Returns true if enough time has passed, and updates the timestamp.
    func allow() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        if now.timeIntervalSince(lastTime) >= interval {
            lastTime = now
            return true
        }
        return false
    }
}
