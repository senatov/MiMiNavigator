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
            // "..." parent entry always stays at the very top, never sorted
            let aIsParent = ParentDirectoryEntry.isParentEntry(a)
            let bIsParent = ParentDirectoryEntry.isParentEntry(b)
            if aIsParent != bIsParent { return aIsParent }

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
        let result: Bool
        switch key {
            case .name:
                result = compareName(a, b, ascending: ascending)
            case .date:
                result = compareDate(a, b, ascending: ascending)
            case .size:
                result = compareSize(a, b, ascending: ascending)
            case .type:
                result = compareType(a, b, ascending: ascending)
            case .permissions:
                result = comparePermissions(a, b, ascending: ascending)
            case .owner:
                result = compareOwner(a, b, ascending: ascending)
            case .childCount:
                result = compareChildCount(a, b, ascending: ascending)
        }
        return result
    }

    private static func compareName(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let cmpResult = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
        return ascending ? (cmpResult == .orderedAscending) : (cmpResult == .orderedDescending)
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

    private static func comparePermissions(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let pa = a.posixPermissions
        let pb = b.posixPermissions
        if pa != pb {
            return ascending ? (pa < pb) : (pa > pb)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }

    private static func compareOwner(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let oa = a.ownerName
        let ob = b.ownerName
        if oa != ob {
            let cmp = oa.localizedCaseInsensitiveCompare(ob)
            return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }

    private static func compareChildCount(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let ca = a.childCountValue
        let cb = b.childCountValue
        if ca != cb {
            return ascending ? (ca < cb) : (ca > cb)
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
                    r2.isDirectory == true
                {
                    return true
                }
            }
        } catch {
            log.error("[FileSortingService] isFolderLike failed: '\(f.nameStr)' - \(error.localizedDescription)")
        }
        return false
    }
}
