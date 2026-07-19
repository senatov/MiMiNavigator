import Foundation
import Testing

@testable import MiMiNavigator

// MARK: - File Content Hash Cache Tests
struct FileContentHashCacheTests {
    @Test func skipsExpensiveAutomaticDirectorySizeRoots() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(DirectorySizeService.isExpensiveAutomaticRoot(home))
        #expect(DirectorySizeService.isExpensiveAutomaticRoot(home.appendingPathComponent("Library")))
        #expect(
            DirectorySizeService.isExpensiveAutomaticRoot(
                home.appendingPathComponent("Library/CloudStorage/OneDrive-Personal")
            )
        )
        #expect(
            !DirectorySizeService.isExpensiveAutomaticRoot(
                home.appendingPathComponent("Library/CloudStorage/OneDrive-Personal/Documents")
            )
        )
        #expect(DirectorySizeService.isExpensiveAutomaticRoot(URL(fileURLWithPath: "/Library/Developer")))
        #expect(!DirectorySizeService.isExpensiveAutomaticRoot(FileManager.default.temporaryDirectory))
    }

    @Test func comparesStreamedContentsAndRevalidatesChanges() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileContentHashCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let firstURL = directory.appendingPathComponent("first.bin")
        let secondURL = directory.appendingPathComponent("second.bin")
        try Data("same-size-a".utf8).write(to: firstURL)
        try Data("same-size-b".utf8).write(to: secondURL)
        let cache = FileContentHashCache(store: nil, namespace: "test")
        #expect(await cache.contentsEqual(firstURL, secondURL) == false)
        try Data("same-size-a".utf8).write(to: secondURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(2)],
            ofItemAtPath: secondURL.path
        )
        #expect(await cache.contentsEqual(firstURL, secondURL) == true)
    }
}
