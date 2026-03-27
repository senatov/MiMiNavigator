// FileSortingService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.

import FileModelKit
import Foundation

enum FileSortingService {

    private enum GroupPriority: Int {
        case parent = 0
        case visibleDirectory = 1
        case hiddenDirectory = 2
        case regularFile = 3
        case alias = 4
    }

    static func sort(_ items: [CustomFile], by key: SortKeysEnum, bDirection: Bool) -> [CustomFile] {
        let sortedItems = items.sorted { left, right in
            let leftPriority = priority(for: left)
            let rightPriority = priority(for: right)

            if leftPriority != rightPriority {
                return leftPriority.rawValue < rightPriority.rawValue
            }

            return compare(left, right, by: key, ascending: bDirection)
        }

        log.debug("[FileSortingService] sorted=\(sortedItems.count) by=\(key) asc=\(bDirection)")
        return sortedItems
    }

    private static func priority(for item: CustomFile) -> GroupPriority {
        if ParentDirectoryEntry.isParentEntry(item) {
            return .parent
        }

        if item.isAlias {
            return .alias
        }

        if isVisibleDirectory(item) {
            return .visibleDirectory
        }

        if isHiddenDirectory(item) {
            return .hiddenDirectory
        }

        return .regularFile
    }

    private static func isVisibleDirectory(_ item: CustomFile) -> Bool {
        isFolderLike(item) && !item.isAppBundle && !isHiddenName(item.nameStr)
    }

    private static func isHiddenDirectory(_ item: CustomFile) -> Bool {
        isFolderLike(item) && !item.isAppBundle && isHiddenName(item.nameStr)
    }

    private static func isHiddenName(_ name: String) -> Bool {
        name.hasPrefix(".") && name != ".."
    }

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

    static func compareName(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let cmpResult = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
        return ascending ? (cmpResult == .orderedAscending) : (cmpResult == .orderedDescending)
    }

    static func compareDate(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let da = a.modifiedDate ?? Date.distantPast
        let db = b.modifiedDate ?? Date.distantPast
        if da != db {
            return ascending ? (da < db) : (da > db)
        }
        return compareName(a, b, ascending: ascending)
    }

    static func compareSize(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let aIsDir = isFolderLike(a) && !a.isAppBundle
        let bIsDir = isFolderLike(b) && !b.isAppBundle
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

    static func compareType(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let ta = a.fileExtension
        let tb = b.fileExtension
        if ta != tb {
            let cmp = ta.localizedCaseInsensitiveCompare(tb)
            return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        }
        return compareName(a, b, ascending: ascending)
    }

    static func comparePermissions(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let pa = a.posixPermissions
        let pb = b.posixPermissions
        if pa != pb {
            return ascending ? (pa < pb) : (pa > pb)
        }
        return compareName(a, b, ascending: ascending)
    }

    static func compareOwner(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let oa = a.ownerName
        let ob = b.ownerName
        if oa != ob {
            let cmp = oa.localizedCaseInsensitiveCompare(ob)
            return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        }
        return compareName(a, b, ascending: ascending)
    }

    static func compareChildCount(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let ca = a.childCountValue
        let cb = b.childCountValue
        if ca != cb {
            return ascending ? (ca < cb) : (ca > cb)
        }
        return compareName(a, b, ascending: ascending)
    }

    // Uses only precomputed scan flags. Sorting must not trigger syscalls.
    private static func isFolderLike(_ f: CustomFile) -> Bool {
        f.isDirectory || f.isSymbolicDirectory
    }
}
