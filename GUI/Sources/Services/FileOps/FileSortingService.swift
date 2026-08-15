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
        case directory = 1
        case regularFile = 2
    }

    static func sort(
        _ items: [CustomFile],
        by key: SortKeysEnum,
        bDirection: Bool,
        excludeDirectoriesFromSorting: Bool = true,
        directoryNameAscending: Bool = true
    ) -> [CustomFile] {
        let sortedItems = items.sorted {
            comesBefore(
                $0,
                $1,
                by: key,
                ascending: bDirection,
                excludeDirectoriesFromSorting: excludeDirectoriesFromSorting,
                directoryNameAscending: directoryNameAscending
            )
        }
        log.debug("[FileSortingService] sorted=\(sortedItems.count) by=\(key) asc=\(bDirection)")
        return sortedItems
    }

    // MARK: - Grouped Comparison
    static func comesBefore(
        _ left: CustomFile,
        _ right: CustomFile,
        by key: SortKeysEnum,
        ascending: Bool,
        excludeDirectoriesFromSorting: Bool = true,
        directoryNameAscending: Bool = true
    ) -> Bool {
        let leftPriority = priority(for: left)
        let rightPriority = priority(for: right)
        if leftPriority != rightPriority {
            return leftPriority.rawValue < rightPriority.rawValue
        }
        if excludeDirectoriesFromSorting && leftPriority == .directory {
            return compareName(left, right, ascending: directoryNameAscending)
        }
        return compare(left, right, by: key, ascending: ascending)
    }

    private static func priority(for item: CustomFile) -> GroupPriority {
        if ParentDirectoryEntry.isParentEntry(item) {
            return .parent
        }

        if isFolderLike(item) && !item.isAppBundle {
            return .directory
        }
        return .regularFile
    }

    static func compare(_ a: CustomFile, _ b: CustomFile, by key: SortKeysEnum, ascending: Bool) -> Bool {
        switch key {
            case .name:
                return compareName(a, b, ascending: ascending)
            case .date:
                return compareDate(a, b, ascending: ascending)
            case .dateCreated:
                return compareDate(a.creationDate, b.creationDate, a: a, b: b, ascending: ascending)
            case .dateLastOpened:
                return compareDate(a.lastOpenedDate, b.lastOpenedDate, a: a, b: b, ascending: ascending)
            case .dateAdded:
                return compareDate(a.dateAdded, b.dateAdded, a: a, b: b, ascending: ascending)
            case .size:
                return compareSize(a, b, ascending: ascending)
            case .type:
                return compareType(a, b, ascending: ascending)
            case .permissions:
                return comparePermissions(a, b, ascending: ascending)
            case .owner:
                return compareOwner(a, b, ascending: ascending)
            case .group:
                return compareText(a.groupName, b.groupName, a: a, b: b, ascending: ascending)
            case .childCount:
                return compareChildCount(a, b, ascending: ascending)
        }
    }

    static func compareName(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let cmpResult = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
        return ascending ? (cmpResult == .orderedAscending) : (cmpResult == .orderedDescending)
    }

    static func compareDate(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        compareDate(a.modifiedDate, b.modifiedDate, a: a, b: b, ascending: ascending)
    }

    private static func compareDate(
        _ da: Date?, _ db: Date?, a: CustomFile, b: CustomFile, ascending: Bool
    ) -> Bool {
        if da == nil || db == nil {
            if da == nil && db != nil { return false }
            if da != nil && db == nil { return true }
            return compareName(a, b, ascending: ascending)
        }
        guard let da, let db else { return false }
        if da != db {
            return ascending ? (da < db) : (da > db)
        }
        return compareName(a, b, ascending: ascending)
    }

    static func compareSize(_ a: CustomFile, _ b: CustomFile, ascending: Bool) -> Bool {
        let sa = sortableSize(for: a)
        let sb = sortableSize(for: b)
        if sa == nil || sb == nil {
            if sa == nil && sb != nil { return false }
            if sa != nil && sb == nil { return true }
            return compareName(a, b, ascending: ascending)
        }
        guard let sa, let sb else { return false }
        if sa != sb {
            return ascending ? (sa < sb) : (sa > sb)
        }
        return compareName(a, b, ascending: ascending)
    }

    private static func sortableSize(for file: CustomFile) -> Int64? {
        if file.isAppBundle { return file.cachedAppSize ?? file.sizeInBytes }
        if !isFolderLike(file) { return file.sizeInBytes }
        if let exact = file.cachedDirectorySize, exact >= 0 { return exact }
        if let shallow = file.cachedShallowSize, shallow >= 0 { return shallow }
        return nil
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
        compareText(a.ownerName, b.ownerName, a: a, b: b, ascending: ascending)
    }

    private static func compareText(
        _ left: String, _ right: String, a: CustomFile, b: CustomFile, ascending: Bool
    ) -> Bool {
        if left != right {
            let cmp = left.localizedCaseInsensitiveCompare(right)
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
