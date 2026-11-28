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

    // MARK: - Column Layout Defaults
    func testFreshLayoutMatchesSavedColumnSelection() throws {
        let bundle = try XCTUnwrap(Bundle.main.url(forResource: "DefaultMimiHome", withExtension: "bundle"))
        let data = try Data(contentsOf: bundle.appendingPathComponent(".mimi/column_layout.json"))
        let bundledLayouts = try JSONDecoder().decode([String: ColumnLayoutModel].self, from: data)
        for side in [FavPanelSide.left, .right] {
            let layout = ColumnLayoutModel(panelSide: side)
            let bundled = try XCTUnwrap(bundledLayouts[side.rawValue.lowercased()])
            XCTAssertEqual(layout.configuredVisibleColumns.map(\.id), [.name, .dateModified, .size, .owner, .childCount])
            XCTAssertEqual(bundled.configuredVisibleColumns.map(\.id), layout.configuredVisibleColumns.map(\.id))
        }
    }

    // MARK: - Manual Name Width
    func testManualNameWidthReturnsWhenPanelHasSpaceAgain() {
        let layout = ColumnLayoutModel(panelSide: .left)
        layout.containerWidth = 900
        layout.nameWidth = 450
        layout.containerWidth = 530
        XCTAssertLessThan(layout.nameWidth, 450)
        XCTAssertEqual(layout.makeSnapshot().nameWidth, 450)
        layout.containerWidth = 900
        XCTAssertEqual(layout.nameWidth, 450)
    }
}
