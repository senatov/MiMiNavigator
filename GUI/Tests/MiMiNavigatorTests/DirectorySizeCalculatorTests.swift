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
        #expect(displaySize == 33)
        #expect(fallbackSize == 33)
        #expect(operationScan.totalBytes == 33)
    }
    @Test func returnsUnavailableWhenCancelled() throws {
        let root = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let cancellation = DirectorySizeCancellationState()
        cancellation.cancel()
        let size = DirectorySizeNativeCalculator.directorySize(root, cancellation: cancellation)
        #expect(size == DirectorySizeService.unavailableSize)
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
