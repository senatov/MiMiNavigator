//  ShallowSizeResultGate.swift
//  MiMiNavigator

import Foundation

// MARK: - Shallow Size Result Gate
final class ShallowSizeResultGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int64?, Never>?
    init(continuation: CheckedContinuation<Int64?, Never>) {
        self.continuation = continuation
    }
    func resolve(_ result: Int64?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: result)
    }
}
