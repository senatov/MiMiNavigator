import FileModelKit
import Foundation
import XCTest
@testable import MiMiNavigator

// MARK: - Scanner Publish Tests
@MainActor
final class ScannerPublishTests: XCTestCase {
    // MARK: - Preserved Metadata
    func testFreshDirectoryObjectWithSameMetadataDoesNotRepublish() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState()
        let scanner = appState.scanner!
        let displayed = CustomFile(path: directory.path)
        displayed.cachedDirectorySize = 4096
        displayed.sizeIsExact = true
        scanner.publishDisplayedFiles([displayed], for: .left)
        let initialVersion = appState.leftFilesVersion
        let unchanged = CustomFile(path: directory.path)
        scanner.publishDisplayedFiles([unchanged], for: .left)
        XCTAssertEqual(appState.leftFilesVersion, initialVersion)
        XCTAssertTrue(appState.displayedLeftFiles[0] === displayed)
        let changed = CustomFile(path: directory.path)
        changed.cachedChildCount = 42
        scanner.publishDisplayedFiles([changed], for: .left)
        XCTAssertEqual(appState.leftFilesVersion, initialVersion + 1)
        XCTAssertEqual(appState.displayedLeftFiles[0].cachedChildCount, 42)
        XCTAssertEqual(appState.displayedLeftFiles[0].cachedDirectorySize, 4096)
    }

    // MARK: - Unavailable Size
    func testUnavailableDirectorySizeDoesNotRepublishRepeatedPatch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let appState = AppState()
        let scanner = appState.scanner!
        let displayed = CustomFile(path: directory.path)
        displayed.cachedDirectorySize = DirectorySizeService.unavailableSize
        scanner.publishDisplayedFiles([displayed], for: .left)
        let initialVersion = appState.leftFilesVersion
        scanner.publishDisplayedFiles([CustomFile(path: directory.path)], for: .left)
        XCTAssertEqual(appState.leftFilesVersion, initialVersion)
        XCTAssertTrue(appState.displayedLeftFiles[0] === displayed)
        let changed = CustomFile(path: directory.path)
        changed.cachedChildCount = (displayed.cachedChildCount ?? 0) + 1
        scanner.publishDisplayedFiles([changed], for: .left)
        XCTAssertEqual(appState.leftFilesVersion, initialVersion + 1)
        XCTAssertNil(appState.displayedLeftFiles[0].cachedDirectorySize)
    }

    // MARK: - Auto Fit Signature
    func testAutoFitSignatureUsesRenderedSize() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = CustomFile(path: directory.path)
        file.cachedDirectorySize = 1_000_000
        let first = ColumnAutoFitMeasurer.renderedContentSignature(columns: [.size], files: [file])
        file.cachedDirectorySize = 1_000_001
        let second = ColumnAutoFitMeasurer.renderedContentSignature(columns: [.size], files: [file])
        file.cachedDirectorySize = 2_000_000
        let third = ColumnAutoFitMeasurer.renderedContentSignature(columns: [.size], files: [file])
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(second, third)
    }
}
