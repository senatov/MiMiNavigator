// TableFileSorter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Local file sorting comparator for FileTableView

import Foundation

// MARK: - Table File Sorter
/// Sorting comparator for file table (directories first)
struct TableFileSorter {
    let sortKey: SortKeysEnum
    let ascending: Bool
    
    /// Compare two files for sorting (directories first)
    func compare(_ a: CustomFile, _ b: CustomFile) -> Bool {
        let aIsFolder = a.isDirectory || a.isSymbolicDirectory
        let bIsFolder = b.isDirectory || b.isSymbolicDirectory
        
        // Directories always come first
        if aIsFolder != bIsFolder {
            return aIsFolder && !bIsFolder
        }
        
        // Then sort by key
        switch sortKey {
        case .name:
            return compareName(a, b)
        case .size:
            return compareSize(a, b)
        case .date:
            return compareDate(a, b)
        case .type:
            return compareType(a, b)
        }
    }
    
    // MARK: - Comparison Methods
    
    private func compareName(_ a: CustomFile, _ b: CustomFile) -> Bool {
        let cmp = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
        return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
    }
    
    private func compareSize(_ a: CustomFile, _ b: CustomFile) -> Bool {
        let lhs = a.sizeInBytes
        let rhs = b.sizeInBytes
        if lhs != rhs {
            return ascending ? (lhs < rhs) : (lhs > rhs)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }
    
    private func compareDate(_ a: CustomFile, _ b: CustomFile) -> Bool {
        let lhs = a.modifiedDate ?? Date.distantPast
        let rhs = b.modifiedDate ?? Date.distantPast
        if lhs != rhs {
            return ascending ? (lhs < rhs) : (lhs > rhs)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }
    
    private func compareType(_ a: CustomFile, _ b: CustomFile) -> Bool {
        let lhs = a.fileExtension
        let rhs = b.fileExtension
        if lhs != rhs {
            let cmp = lhs.localizedCaseInsensitiveCompare(rhs)
            return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        }
        return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
    }
}
