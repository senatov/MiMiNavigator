// FileRecycleService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Finder-compatible recycling for local and File Provider items.

import AppKit
import Foundation

// MARK: - File Recycle Service

@MainActor
enum FileRecycleService {
    // MARK: - Recycle Item
    static func recycle(_ url: URL) async throws -> URL? {
        do {
            return try await recycleOnce(url)
        } catch {
            guard isTransientFileProviderPermissionError(error, for: url) else { throw error }
            try await Task.sleep(for: .milliseconds(200))
            return try await recycleOnce(URL(fileURLWithPath: url.path))
        }
    }

    // MARK: - Recycle Once
    private static func recycleOnce(_ url: URL) async throws -> URL? {
        let recycledURLs = try await NSWorkspace.shared.recycle([url])
        return recycledURLs[url]
    }

    // MARK: - Transient File Provider Error
    private static func isTransientFileProviderPermissionError(_ error: Error, for url: URL) -> Bool {
        guard url.path.contains("/Library/CloudStorage/") || url.path.contains("/Library/Mobile Documents/") else {
            return false
        }
        let nsError = error as NSError
        let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        return [nsError, underlyingError].compactMap { $0 }.contains {
            ($0.domain == NSCocoaErrorDomain && $0.code == NSFileWriteNoPermissionError)
                || ($0.domain == NSPOSIXErrorDomain && ($0.code == EPERM || $0.code == EACCES))
        }
    }
}
