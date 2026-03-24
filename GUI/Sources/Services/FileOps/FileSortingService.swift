// FileSortingService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: File sorting logic with directories-first behavior

import FileModelKit
import Foundation

// MARK: - File Sorting Service
/// Handles sorting of file lists with configurable sort key and direction
enum FileSortingService {

    // MARK: - Public Methods

    /// Sort files with directories first, then by specified key
    static func sort(_ items: [CustomFile], by key: SortKeysEnum, bDirection: Bool) -> [CustomFile] {

        // Stable grouping priority:
        // 0 - parent ("..")
        // 1 - directories (including symlink dirs, excluding .app)
        // 2 - regular files
        // 3 - aliases (always last)
        func priority(_ item: CustomFile) -> Int {
            if ParentDirectoryEntry.isParentEntry(item) { return 0 }

            if item.isAlias {
                return 3
            }

            if isFolderLike(item) && !item.isAppBundle {
                return 1
            }

            return 2
        }

        let sorted = items.sorted { a, b in
            // Parent entry must always stay at top regardless of sort direction
            let pa = priority(a)
            let pb = priority(b)

            // ALWAYS enforce grouping first (critical fix)
            if pa != pb {
                return pa < pb
            }

            // Within same group — apply user-selected sort
            return compare(a, b, by: key, ascending: bDirection)
        }

        log.debug("[FileSortingService] sorted \(sorted.count) items by=\(key) asc=\(bDirection) (grouped)")
        return sorted
    }

    // MARK: - Private Methods
    static func compare(_ a: CustomFile, _ b: CustomFile, by key: SortKeysEnum, ascending: Bool) -> Bool {
        switch key {
            case .name:
                return compareName(a, b, ascending: ascending)
            case .date:
                return compareDate(a, b, ascending: ascending)
            case .size:
                return compareSize(a, b, ascending: ascending)
            case .type:
                return compareType(a, b, ascending: ascending)
            case .permissions:
                return comparePermissions(a, b, ascending: ascending)
            case .owner:
                return compareOwner(a, b, ascending: ascending)
            case .childCount:
                return compareChildCount(a, b, ascending: ascending)
        }
    }

    // MARK: -
    static func compareName(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let cmpResult = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
        return ascending ? (cmpResult == .orderedAscending) : (cmpResult == .orderedDescending)
    }

    // MARK: -
    static func compareDate(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let da = a.modifiedDate ?? Date.distantPast
        let db = b.modifiedDate ?? Date.distantPast
        if da != db {
            return ascending ? (da < db) : (da > db)
        }
        return compareName(a, b, ascending: ascending)
    }

    // MARK: -
    static func compareSize(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let aIsDir = isFolderLike(a) && !a.isAppBundle
        let bIsDir = isFolderLike(b) && !b.isAppBundle
        // Directories have no meaningful file size — sort them by name within their group
        if aIsDir && bIsDir {
            return compareName(a, b, ascending: ascending)
        }
        let sa = a.isAppBundle ? (a.cachedAppSize ?? 0) : a.sizeInBytes
        let sb = b.isAppBundle ? (b.cachedAppSize ?? 0) : b.sizeInBytes
        if sa != sb {
            return ascending ? (sa < sb) : (sa > sb)
        }
        return compareName(a, b, ascending: ascending)
    }

    // MARK: -
    static func compareType(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let ta = a.fileExtension
        let tb = b.fileExtension
        if ta != tb {
            let cmp = ta.localizedCaseInsensitiveCompare(tb)
            return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        }
        return compareName(a, b, ascending: ascending)
    }

    // MARK: -
    static func comparePermissions(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let pa = a.posixPermissions
        let pb = b.posixPermissions
        if pa != pb {
            return ascending ? (pa < pb) : (pa > pb)
        }
        return compareName(a, b, ascending: ascending)
    }

    // MARK: -
    static func compareOwner(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let oa = a.ownerName
        let ob = b.ownerName
        if oa != ob {
            let cmp = oa.localizedCaseInsensitiveCompare(ob)
            return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        }
        return compareName(a, b, ascending: ascending)
    }

    // MARK: -
    static func compareChildCount(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let ca = a.childCountValue
        let cb = b.childCountValue
        if ca != cb {
            return ascending ? (ca < cb) : (ca > cb)
        }
        return compareName(a, b, ascending: ascending)
    }

    // MARK: - Check if file should be treated as folder
    // Uses only pre-computed flags from scan — no syscalls during sort
    private static func isFolderLike(_ f: CustomFile) -> Bool {
        f.isDirectory || f.isSymbolicDirectory
    }
}
