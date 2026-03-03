// SortIndexCache.swift
// MiMiNavigator
//
// Created by Claude on 04.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Pre-computed sort indices for instant sort switching.
//              Builds all sort variants in background, switching is O(1).

import Foundation
import FileModelKit

// MARK: - All sort keys (SortKeysEnum doesn't have CaseIterable)
private let allSortKeys: [SortKeysEnum] = [.name, .date, .size, .type, .permissions, .owner, .childCount]

// MARK: - Sort Index Cache
/// Maintains pre-computed sort indices for all sort keys.
/// Rebuilding happens async in background, sort switching is instant.
@MainActor
final class SortIndexCache {
    
    // Indices: sortKey → array of original indices in sorted order
    private var ascendingIndices: [SortKeysEnum: [Int]] = [:]
    private var descendingIndices: [SortKeysEnum: [Int]] = [:]
    
    // Version tracking to avoid stale updates
    private var currentVersion: Int = 0
    private var isRebuilding: Bool = false
    
    // MARK: - Rebuild all indices (async, background)
    
    /// Rebuild all sort indices for new file list.
    /// Call this when directory changes. Runs in background.
    func rebuild(files: [CustomFile]) async {
        let version = currentVersion + 1
        currentVersion = version
        isRebuilding = true
        
        let t0 = Date()
        log.debug("[SortIndexCache] rebuild START for \(files.count) files, version=\(version)")
        
        // Build indices in background
        let allKeys = allSortKeys
        
        // Pre-cache expensive computed properties
        let cached = files.enumerated().map { (idx, file) -> CachedFileForSort in
            CachedFileForSort(
                index: idx,
                name: file.nameStr.lowercased(),
                size: file.sizeInBytes,
                date: file.modifiedDate ?? Date.distantPast,
                kind: file.kindFormatted.lowercased(),
                permissions: file.permissionsFormatted,
                owner: file.ownerFormatted.lowercased(),
                childCount: file.cachedChildCount ?? 0,
                isDirectory: file.isDirectory
            )
        }
        
        // Build indices for each sort key in parallel
        await withTaskGroup(of: (SortKeysEnum, [Int], [Int]).self) { group in
            for key in allKeys {
                group.addTask { @Sendable in
                    let ascending = Self.buildIndex(cached: cached, by: key, ascending: true)
                    let descending = Self.buildIndex(cached: cached, by: key, ascending: false)
                    return (key, ascending, descending)
                }
            }
            
            for await (key, asc, desc) in group {
                // Check version to avoid applying stale results
                if self.currentVersion == version {
                    self.ascendingIndices[key] = asc
                    self.descendingIndices[key] = desc
                }
            }
        }
        
        isRebuilding = false
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        log.debug("[SortIndexCache] rebuild DONE in \(ms)ms, version=\(version)")
    }
    
    // MARK: - Get sorted files (O(n) but no sorting, just index lookup)
    
    /// Returns files in sorted order. Uses pre-computed indices — no sorting needed.
    func sortedFiles(_ files: [CustomFile], by key: SortKeysEnum, ascending: Bool) -> [CustomFile] {
        let indices = ascending ? ascendingIndices[key] : descendingIndices[key]
        
        guard let idx = indices, idx.count == files.count else {
            // Fallback: indices not ready or count mismatch, sort directly
            log.warning("[SortIndexCache] fallback sort for key=\(key) asc=\(ascending)")
            return files.sorted { compare($0, $1, by: key, ascending: ascending) }
        }
        
        // Map indices to files — O(n) but very fast
        return idx.map { files[$0] }
    }
    
    // MARK: - Check if cache is valid
    
    var isValid: Bool {
        !ascendingIndices.isEmpty && !isRebuilding
    }
    
    // MARK: - Clear cache
    
    func clear() {
        ascendingIndices.removeAll()
        descendingIndices.removeAll()
        currentVersion += 1
    }
    
    // MARK: - Private: Build index for one sort key (nonisolated for background execution)
    
    nonisolated private static func buildIndex(cached: [CachedFileForSort], by key: SortKeysEnum, ascending: Bool) -> [Int] {
        let sorted = cached.sorted { a, b in
            let result = compareForSort(a, b, by: key)
            return ascending ? result : !result
        }
        return sorted.map { $0.index }
    }
    
    // MARK: - Private: Compare cached items (nonisolated for background execution)
    
    nonisolated private static func compareForSort(_ a: CachedFileForSort, _ b: CachedFileForSort, by key: SortKeysEnum) -> Bool {
        // Directories first (Total Commander style)
        if a.isDirectory != b.isDirectory {
            return a.isDirectory
        }
        
        switch key {
        case .name:
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        case .size:
            return a.size < b.size
        case .date:
            return a.date < b.date
        case .type:
            if a.kind != b.kind {
                return a.kind < b.kind
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        case .permissions:
            return a.permissions < b.permissions
        case .owner:
            return a.owner < b.owner
        case .childCount:
            return a.childCount < b.childCount
        }
    }
    
    // MARK: - Fallback compare for direct sorting
    
    private func compare(_ a: CustomFile, _ b: CustomFile, by key: SortKeysEnum, ascending: Bool) -> Bool {
        // Directories first
        if a.isDirectory != b.isDirectory {
            return a.isDirectory
        }
        
        let result: Bool
        switch key {
        case .name:
            result = a.nameStr.localizedStandardCompare(b.nameStr) == .orderedAscending
        case .size:
            result = a.sizeInBytes < b.sizeInBytes
        case .date:
            result = (a.modifiedDate ?? .distantPast) < (b.modifiedDate ?? .distantPast)
        case .type:
            result = a.kindFormatted < b.kindFormatted
        case .permissions:
            result = a.permissionsFormatted < b.permissionsFormatted
        case .owner:
            result = a.ownerFormatted < b.ownerFormatted
        case .childCount:
            result = (a.cachedChildCount ?? 0) < (b.cachedChildCount ?? 0)
        }
        
        return ascending ? result : !result
    }
}

// MARK: - Cached file data for sorting (avoids repeated property access)

private struct CachedFileForSort: Sendable {
    let index: Int
    let name: String
    let size: Int64
    let date: Date
    let kind: String
    let permissions: String
    let owner: String
    let childCount: Int
    let isDirectory: Bool
}
