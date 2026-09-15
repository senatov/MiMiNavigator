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

// MARK: - Icon Content Inspection Tests
struct IconContentInspectionTests {
    @Test func skipsCloudRootsWithoutRejectingSimilarLocalNames() {
        #expect(!IconContentInspection.allowsContentRead(path: "/Users/test/Library/CloudStorage/OneDrive/a.zip"))
        #expect(!IconContentInspection.allowsContentRead(path: "/Users/test/Library/Mobile Documents/a.zip"))
        #expect(IconContentInspection.allowsContentRead(path: "/Users/test/Library/CloudStorage-backup/a.zip"))
    }
    @Test func detectsLocalZipButSkipsCloudZipAndItsAlias() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = root.appendingPathComponent("Library/CloudStorage/Test")
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let localURL = root.appendingPathComponent("local.zip")
        let cloudURL = cloud.appendingPathComponent("cloud.zip")
        let aliasURL = root.appendingPathComponent("alias.zip")
        let header = Data([0x50, 0x4b, 0x03, 0x04, 0, 0, 1, 0])
        try header.write(to: localURL)
        try header.write(to: cloudURL)
        try FileManager.default.createSymbolicLink(at: aliasURL, withDestinationURL: cloudURL)
        let results = await Task.detached {
            [localURL, cloudURL, aliasURL].map {
                IconContentInspection.inspect(url: $0, isDirectory: false).isEncrypted
            }
        }.value
        #expect(results == [true, false, false])
    }
}
