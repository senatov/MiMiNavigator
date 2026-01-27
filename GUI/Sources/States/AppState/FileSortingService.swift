// FileSortingService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: File sorting logic with directories-first behavior

import Foundation

// MARK: - File Sorting Service
/// Handles sorting of file lists with configurable sort key and direction
enum FileSortingService {
    
    // MARK: - Public Methods
    
    /// Sort files with directories first, then by specified key
    static func sort(
        _ items: [CustomFile],
        by key: SortKeysEnum,
        ascending: Bool
    ) -> [CustomFile] {
        let sorted = items.sorted { a, b in
            // Directories always come first
            let aIsFolder = isFolderLike(a)
            let bIsFolder = isFolderLike(b)
            
            if aIsFolder != bIsFolder {
                return aIsFolder && !bIsFolder
            }
            
            // Then sort by key
            return compare(a, b, by: key, ascending: ascending)
        }
        
        log.debug("[FileSortingService] sorted \(sorted.count) items by=\(key) asc=\(ascending)")
        return sorted
    }
    
    // MARK: - Private Methods
    
    private static func compare(
        _ a: CustomFile,
        _ b: CustomFile,
        by key: SortKeysEnum,
        ascending: Bool
    ) -> Bool {
        switch key {
        case .name:
            return compareName(a, b, ascending: ascending)
        case .date:
            return compareDate(a, b, ascending: ascending)
        case .size:
            return compareSize(a, b, ascending: ascending)
        case .type:
            return compareType(a, b, ascending: ascending)
        }
    }
    
    private static func compareName(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let result = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
        if result != .orderedSame {
            return ascending ? (result == .orderedAscending) : (result == .orderedDescending)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }
    
    private static func compareDate(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let da = a.modifiedDate ?? Date.distantPast
        let db = b.modifiedDate ?? Date.distantPast
        if da != db {
            return ascending ? (da < db) : (da > db)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }
    
    private static func compareSize(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let sa = a.sizeInBytes
        let sb = b.sizeInBytes
        if sa != sb {
            return ascending ? (sa < sb) : (sa > sb)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }
    
    private static func compareType(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let ta = a.fileExtension
        let tb = b.fileExtension
        if ta != tb {
            let cmp = ta.localizedCaseInsensitiveCompare(tb)
            return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }

    /// Check if file should be treated as folder (includes symlinks to dirs)
    private static func isFolderLike(_ f: CustomFile) -> Bool {
        if f.isDirectory || f.isSymbolicDirectory {
            return true
        }
        
        let url = f.urlValue
        do {
            let rv = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if rv.isSymbolicLink == true {
                let dst = url.resolvingSymlinksInPath()
                if let r2 = try? dst.resourceValues(forKeys: [.isDirectoryKey]),
                   r2.isDirectory == true {
                    return true
                }
            }
        } catch {
            log.error("[FileSortingService] isFolderLike failed: \(url.path) - \(error.localizedDescription)")
        }
        return false
    }
}
