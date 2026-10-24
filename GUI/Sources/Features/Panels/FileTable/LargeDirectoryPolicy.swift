// LargeDirectoryPolicy.swift
// MiMiNavigator
// Description: Bounded presentation and measurement for flat directories.

import FileModelKit
import Foundation

// MARK: - Large Directory Policy
enum LargeDirectoryPolicy {
    static let largeEntryCount = 2_000
    static let veryLargeEntryCount = 50_000
    static let nearbyScreenCount = 3
    static let backgroundSampleCount = 300

    // MARK: - Mode
    static func mode(for count: Int) -> String {
        if count >= veryLargeEntryCount { return "very-large" }
        if count >= largeEntryCount { return "large" }
        return "standard"
    }

    // MARK: - Visible Window
    static func visibleWindow(count: Int, firstVisible: Int, visibleCount: Int) -> Range<Int> {
        guard count > 0 else { return 0..<0 }
        if count < largeEntryCount { return 0..<count }
        let screen = max(1, visibleCount)
        let first = min(max(0, firstVisible), count - 1)
        let lower = max(0, first - nearbyScreenCount * screen)
        let upper = min(count, first + (nearbyScreenCount + 1) * screen)
        return lower..<upper
    }

    // MARK: - Background Sample
    static func backgroundSample<T>(from items: [T], excluding window: Range<Int>) -> [T] {
        guard !items.isEmpty else { return [] }
        let excludedStart = min(max(0, window.lowerBound), items.count)
        let excludedEnd = min(max(excludedStart, window.upperBound), items.count)
        let excludedCount = excludedEnd - excludedStart
        let outsideCount = items.count - excludedCount
        guard outsideCount > 0 else { return [] }
        let step = max(1, (outsideCount + backgroundSampleCount - 1) / backgroundSampleCount)
        var sampled: [T] = []
        sampled.reserveCapacity(min(outsideCount, backgroundSampleCount))
        for outsideIndex in Swift.stride(from: 0, to: outsideCount, by: step) {
            let index = outsideIndex < excludedStart ? outsideIndex : outsideIndex + excludedCount
            sampled.append(items[index])
        }
        return sampled
    }
}

// MARK: - Sorted File Table Snapshot
struct FileTableSortedSnapshot: Sendable {
    let rows: [CustomFile]
    let indexByID: [CustomFile.ID: Int]
    let containsDirectories: Bool
    let containsUsablePermissions: Bool
    let reusedInputOrder: Bool

    // MARK: - Build
    static func build(files: [CustomFile], sorter: TableFileSorter) -> Self {
        let alreadySorted = files.count >= LargeDirectoryPolicy.largeEntryCount && isAlreadySorted(files, by: sorter)
        let sorted = alreadySorted ? files : files.sorted(by: sorter.compare)
        if Task.isCancelled {
            return Self(rows: [], indexByID: [:], containsDirectories: false, containsUsablePermissions: false, reusedInputOrder: false)
        }
        let hasParentEntry = sorted.contains { $0.isParentEntry || $0.nameStr == ".." }
        let rows = hasParentEntry ? sorted.filter { !$0.isParentEntry && $0.nameStr != ".." } : sorted
        var index = [CustomFile.ID: Int](minimumCapacity: rows.count)
        var containsDirectories = false
        var containsUsablePermissions = false
        for (offset, file) in rows.enumerated() {
            index[file.id] = offset
            if file.isDirectory { containsDirectories = true }
            if file.posixPermissions != 0 { containsUsablePermissions = true }
        }
        return Self(
            rows: rows,
            indexByID: index,
            containsDirectories: containsDirectories,
            containsUsablePermissions: containsUsablePermissions,
            reusedInputOrder: alreadySorted
        )
    }

    // MARK: - Existing Order
    private static func isAlreadySorted(_ files: [CustomFile], by sorter: TableFileSorter) -> Bool {
        for index in 1..<files.count {
            if sorter.compare(files[index], files[index - 1]) { return false }
        }
        return true
    }
}
