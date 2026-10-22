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
        let outsideCount = items.count - min(items.count, window.count)
        guard outsideCount > 0 else { return [] }
        let stride = max(1, (outsideCount + backgroundSampleCount - 1) / backgroundSampleCount)
        var sampled: [T] = []
        sampled.reserveCapacity(min(outsideCount, backgroundSampleCount))
        var outsideIndex = 0
        for index in items.indices where !window.contains(index) {
            if outsideIndex % stride == 0 { sampled.append(items[index]) }
            outsideIndex += 1
        }
        return sampled
    }
}

// MARK: - Sorted File Table Snapshot
struct FileTableSortedSnapshot: Sendable {
    let files: [CustomFile]
    let rows: [CustomFile]
    let indexByID: [CustomFile.ID: Int]
    let containsDirectories: Bool

    // MARK: - Build
    static func build(files: [CustomFile], sorter: TableFileSorter) -> Self {
        let sorted = files.sorted(by: sorter.compare)
        if Task.isCancelled { return Self(files: [], rows: [], indexByID: [:], containsDirectories: false) }
        let rows = sorted.filter { !$0.isParentEntry && $0.nameStr != ".." }
        var index = [CustomFile.ID: Int](minimumCapacity: rows.count)
        var containsDirectories = false
        for (offset, file) in rows.enumerated() {
            index[file.id] = offset
            if file.isDirectory { containsDirectories = true }
        }
        return Self(files: sorted, rows: rows, indexByID: index, containsDirectories: containsDirectories)
    }
}
