// ApplicationPersistentCache.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared CacheKit database for application cache namespaces.

import CacheKit
import Foundation

// MARK: - Application Persistent Cache
enum ApplicationPersistentCache {
    static let shared: PersistentCacheStore? = {
        do {
            let baseURL = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let databaseURL =
                baseURL
                .appendingPathComponent("MiMiNavigator", isDirectory: true)
                .appendingPathComponent("cache.sqlite")
            return try PersistentCacheStore(databaseURL: databaseURL)
        } catch {
            log.error("[Cache] persistent store unavailable: \(error.localizedDescription)")
            return nil
        }
    }()
}
