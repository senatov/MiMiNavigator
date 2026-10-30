import CryptoKit
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
// MARK: - Cleanup Scan Safety Tests
struct JunkScanSafetyTests {
    @Test func resumesAfterTheLastCommittedDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JunkScanCheckpoint-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let child = root.appendingPathComponent("next", isDirectory: true)
        let file = root.appendingPathComponent("one.bin")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data("one".utf8).write(to: file)
        let databaseURL = root.appendingPathComponent("checkpoint.sqlite")
        let first = JunkScanDatabase(databaseURL: databaseURL)
        #expect(try await first.beginTraversal(root: root) == 0)
        #expect(await first.nextDirectory(root: root) == root)
        let record = JunkFileRecord(url: file, size: 3, modified: Date(timeIntervalSince1970: 1000))
        let batch = JunkDirectoryBatch(directory: root, childDirectories: [child], files: [record], candidates: [], visited: 2)
        #expect(await first.saveDirectory(batch, root: root))
        let resumed = JunkScanDatabase(databaseURL: databaseURL)
        #expect(try await resumed.beginTraversal(root: root) == 2)
        #expect(await resumed.nextDirectory(root: root) == child)
        #expect(await resumed.traversalData(root: root).files.map(\.url) == [file])
        let last = JunkDirectoryBatch(directory: child, childDirectories: [], files: [], candidates: [], visited: 0)
        #expect(await resumed.saveDirectory(last, root: root))
        #expect(await resumed.nextDirectory(root: root) == nil)
        try await resumed.finishTraversal(root: root)
        let otherRoot = root.appendingPathComponent("other", isDirectory: true)
        let otherFile = otherRoot.appendingPathComponent("two.bin")
        try FileManager.default.createDirectory(at: otherRoot, withIntermediateDirectories: true)
        try Data("two".utf8).write(to: otherFile)
        #expect(try await resumed.beginTraversal(root: otherRoot) == 0)
        let otherRecord = JunkFileRecord(url: otherFile, size: 3, modified: Date(timeIntervalSince1970: 1000))
        let otherBatch = JunkDirectoryBatch(directory: otherRoot, childDirectories: [], files: [otherRecord], candidates: [], visited: 1)
        #expect(await resumed.saveDirectory(otherBatch, root: otherRoot))
        try await resumed.finishTraversal(root: otherRoot)
        #expect(await resumed.globalDuplicateRecords().count == 2)
    }

    @Test func rejectsDuplicateWhoseContentsChanged() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JunkDuplicateSafety-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("copy.bin")
        let original = Data("same-size-a".utf8)
        try original.write(to: file)
        let digest = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        let candidate = JunkCandidate(url: file, kind: .duplicate, reason: "test", size: Int64(original.count), group: "\(original.count):\(digest)")
        #expect(await JunkScanEngine.stillMatchesCandidate(candidate))
        try Data("same-size-b".utf8).write(to: file)
        #expect(!(await JunkScanEngine.stillMatchesCandidate(candidate)))
    }

    @Test func excludesDevelopmentTreeFromCleanupCandidates() throws {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Develop/Project/Sources/Copy.swift").path
        #expect(JunkScanEngine.shouldExclude(path))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JunkRepositoryGuard-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        #expect(JunkScanEngine.shouldExclude(root.appendingPathComponent("Sources/Copy.swift").path))
        let cloud = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("My Drive/Public/Photo.jpg").path
        #expect(JunkScanEngine.shouldExclude(cloud))
    }

    @Test func onlySuggestsOldFoldersThatRemainEmpty() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("JunkEmptyFolder-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #expect(!JunkScanEngine.isEligibleEmptyFolder(folder))
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-100 * 86400)], ofItemAtPath: folder.path)
        #expect(JunkScanEngine.isEligibleEmptyFolder(folder))
        try Data("keep".utf8).write(to: folder.appendingPathComponent("keep.txt"))
        #expect(!JunkScanEngine.isEligibleEmptyFolder(folder))
    }
}
