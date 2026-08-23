// DirectorySizeSecurityScope.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Best-effort security-scoped access for directory size reads.

import Foundation

// MARK: - Directory Size Security Scope
enum DirectorySizeSecurityScope {
    // MARK: - Access
    static func access<T>(_ url: URL, work: () throws -> T) rethrows -> T {
        let didStart = url.isFileURL && url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        return try work()
    }
}
