// DirectorySizeCalculatorTests.swift
// MiMiNavigatorTests

import Foundation
import Testing
@testable import MiMiNavigator

// MARK: - Directory Size Calculator Tests
struct DirectorySizeCalculatorTests {
    @Test func countsLogicalBytesIncludingHiddenAndPackageContents() async throws {
        let root = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cancellation = DirectorySizeCancellationState()
        let displaySize = DirectorySizeNativeCalculator.directorySize(root, cancellation: cancellation)
        let fallbackSize = DirectorySizeNativeCalculator.fallbackDirectorySize(root, cancellation: cancellation)
        let operationScan = await DirSizeCalculator.scan([root])
        #expect(displaySize.size == 33)
        #expect(displaySize.status == "exact")
        #expect(fallbackSize == 33)
        #expect(operationScan.totalBytes == 33)
    }
    @Test func returnsUnavailableWhenCancelled() throws {
        let root = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cancellation = DirectorySizeCancellationState()
        cancellation.cancel()
        let size = DirectorySizeNativeCalculator.directorySize(root, cancellation: cancellation)
        #expect(size.isCancelled)
        #expect(size.size == DirectorySizeService.unavailableSize)
    }
    @Test func distinguishesScanBudgetFromUnreadableDirectory() throws {
        let root = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<520 {
            let file = root.appendingPathComponent("entry-\(index)")
            try Data().write(to: file)
        }
        let result = DirectorySizeNativeCalculator.directorySize(
            root,
            cancellation: DirectorySizeCancellationState(),
            maximumEntryCount: 1,
            maximumDuration: 8
        )
        #expect(result.isBudgetExceeded)
        #expect(result.size == DirectorySizeService.unavailableSize)
    }
    // MARK: - Fixture
    private func makeFixtureDirectory() throws -> URL {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("MiMiDirectorySizeTests-\(UUID().uuidString)")
        let package = root.appendingPathComponent("Sample.app", isDirectory: true)
        try fileManager.createDirectory(at: package, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 10).write(to: root.appendingPathComponent("visible.bin"))
        try Data(repeating: 2, count: 11).write(to: root.appendingPathComponent(".hidden.bin"))
        try Data(repeating: 3, count: 12).write(to: package.appendingPathComponent("payload.bin"))
        return root
    }
}

// MARK: - Large Directory Policy Tests
struct LargeDirectoryPolicyTests {
    @Test func keepsSmallDirectoriesComplete() {
        #expect(LargeDirectoryPolicy.visibleWindow(count: 1_999, firstVisible: 900, visibleCount: 30) == (0..<1_999))
        #expect(LargeDirectoryPolicy.mode(for: 1_999) == "standard")
        #expect(LargeDirectoryPolicy.mode(for: 2_000) == "large")
        #expect(LargeDirectoryPolicy.mode(for: 49_999) == "large")
        #expect(LargeDirectoryPolicy.mode(for: 50_000) == "very-large")
    }
    @Test func boundsVisibleRowsAtTheStartMiddleAndEnd() {
        #expect(LargeDirectoryPolicy.visibleWindow(count: 19_367, firstVisible: 0, visibleCount: 30) == (0..<120))
        #expect(LargeDirectoryPolicy.visibleWindow(count: 19_367, firstVisible: 10_000, visibleCount: 30) == (9_910..<10_120))
        #expect(LargeDirectoryPolicy.visibleWindow(count: 200_000, firstVisible: 199_990, visibleCount: 30) == (199_900..<200_000))
    }
    @Test func samplesTheRestWithoutIncludingVisibleRows() {
        let items = Array(0..<200_000)
        let window = LargeDirectoryPolicy.visibleWindow(count: items.count, firstVisible: 100_000, visibleCount: 30)
        let sample = LargeDirectoryPolicy.backgroundSample(from: items, excluding: window)
        #expect(sample.count <= LargeDirectoryPolicy.backgroundSampleCount)
        #expect(sample.allSatisfy { !window.contains($0) })
        #expect(sample.first == 0)
        #expect(sample.last ?? 0 > 190_000)
    }
    @Test func samplesAcrossWindowEdgesWithoutScanningEveryEntry() {
        let items = Array(0..<1_000)
        let middle = LargeDirectoryPolicy.backgroundSample(from: items, excluding: 400..<500)
        #expect(middle.count == 300)
        #expect(middle[133] == 399)
        #expect(middle[134] == 502)
        #expect(middle.last == 997)
        #expect(LargeDirectoryPolicy.backgroundSample(from: items, excluding: 0..<100).first == 100)
        #expect(LargeDirectoryPolicy.backgroundSample(from: items, excluding: 900..<1_000).last == 897)
        #expect(LargeDirectoryPolicy.backgroundSample(from: items, excluding: 0..<1_000).isEmpty)
        #expect(LargeDirectoryPolicy.backgroundSample(from: items, excluding: 1_100..<1_200).first == 0)
    }
}
