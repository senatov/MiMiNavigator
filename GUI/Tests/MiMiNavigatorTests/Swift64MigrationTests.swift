// Swift64MigrationTests.swift
// MiMiNavigatorTests

import FileModelKit
import FindFilesKit
import Foundation
import Testing
import XCTest
@testable import MiMiNavigator

// MARK: - Stream Copy Tests
struct StreamCopyTests {
    @Test func writesEveryByteWhenOutputAcceptsOnlySmallChunks() {
        let source = Data((0..<32).map(UInt8.init))
        var written = Data()
        var progress: Int64 = 0
        let success = source.withUnsafeBytes { rawBuffer in
            FileOpsEngine.writeFully(
                rawBuffer.bindMemory(to: UInt8.self).baseAddress!,
                count: source.count,
                write: { pointer, remaining in
                    let accepted = min(3, remaining)
                    written.append(pointer, count: accepted)
                    return accepted
                },
                onChunk: { progress += $0 }
            )
        }
        #expect(success)
        #expect(written == source)
        #expect(progress == Int64(source.count))
    }

    @Test func failsWhenOutputMakesNoProgress() {
        let source: [UInt8] = [1, 2, 3]
        var progress: Int64 = 0
        let success = source.withUnsafeBufferPointer { buffer in
            FileOpsEngine.writeFully(buffer.baseAddress!, count: buffer.count, write: { _, _ in 0 }, onChunk: { progress += $0 })
        }
        #expect(!success)
        #expect(progress == 0)
    }

    @Test func copiesMoreThanOneBufferWithoutChangingContents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiMiStreamCopy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("source.bin")
        let destination = directory.appendingPathComponent("destination.bin")
        let expected = Data((0..<(1_048_576 + 113)).map { UInt8(truncatingIfNeeded: $0) })
        try expected.write(to: source)
        try FileOpsEngine.performStreamCopy(from: source, to: destination).get()
        #expect(try Data(contentsOf: destination) == expected)
    }
}

// MARK: - Scan Timeout Tests
private final class SuspendedScan: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    // MARK: - Wait
    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if isReleased {
                lock.unlock()
                continuation.resume()
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    // MARK: - Release
    func release() {
        lock.lock()
        isReleased = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}

// MARK: - Scan Timeout Tests
struct ScanTimeoutTests {
    // MARK: - Scan Failure
    private struct ScanFailure: Error {}

    @Test func returnsScanResultBeforeDeadline() async throws {
        let scanTask = Task<[CustomFile], Error> { [] }
        let files = try await ScanTimeoutRace.run(scanTask, url: URL(fileURLWithPath: "/tmp"), timeout: 30)
        #expect(files.isEmpty)
    }

    @Test func cancelsScanAtDeadline() async {
        let scanTask = Task<[CustomFile], Error> {
            try await Task.sleep(for: .seconds(30))
            return []
        }
        do {
            _ = try await ScanTimeoutRace.run(scanTask, url: URL(fileURLWithPath: "/tmp"), timeout: 8, waitForTimeout: { _ in })
            Issue.record("Expected a scan timeout")
        } catch let error as ScanTimeoutError {
            #expect(error.seconds == 8)
            #expect(scanTask.isCancelled)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func preservesScanFailure() async {
        let scanTask = Task<[CustomFile], Error> { throw ScanFailure() }
        do {
            _ = try await ScanTimeoutRace.run(scanTask, url: URL(fileURLWithPath: "/tmp"), timeout: 30)
            Issue.record("Expected the original scan failure")
        } catch is ScanFailure {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func propagatesCallerCancellationToScan() async {
        let scanTask = Task<[CustomFile], Error> {
            try await Task.sleep(for: .seconds(30))
            return []
        }
        let caller = Task {
            try await ScanTimeoutRace.run(scanTask, url: URL(fileURLWithPath: "/tmp"), timeout: 30)
        }
        caller.cancel()
        do {
            _ = try await caller.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(scanTask.isCancelled)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func callerCancellationDoesNotWaitForBlockedScan() async {
        let gate = SuspendedScan()
        defer { gate.release() }
        let scanTask = Task.detached { () throws -> [CustomFile] in
            await gate.wait()
            return []
        }
        let caller = Task {
            try await ScanTimeoutRace.run(scanTask, url: URL(fileURLWithPath: "/tmp"), timeout: 0.2)
        }
        caller.cancel()
        do {
            _ = try await caller.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(scanTask.isCancelled)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - Git Status Subprocess Tests
struct GitStatusSubprocessTests {
    @Test func ignoresGitShimWhenNoDeveloperToolchainIsAvailable() {
        #expect(GitExecutableLocator.resolve(developerDirectory: nil, additionalPaths: []) == nil)
    }

    @Test func usesExecutableFromSelectedDeveloperDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiMiGitTool-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let bin = directory.appendingPathComponent("usr/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let git = bin.appendingPathComponent("git")
        try Data().write(to: git)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: git.path)
        #expect(GitExecutableLocator.resolve(developerDirectory: directory.path, additionalPaths: []) == git.path)
    }

    @Test func preservesNulDelimitedPathsWithWhitespace() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiMiGitStatus-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let git = Process()
        git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        git.arguments = ["-C", directory.path, "init", "-q"]
        try git.run()
        git.waitUntilExit()
        #expect(git.terminationStatus == 0)
        let fileName = "a name with a\nnewline.txt"
        try Data("content".utf8).write(to: directory.appendingPathComponent(fileName))
        let snapshot = await GitStatusService.shared.snapshot(for: directory)
        #expect(snapshot?.repositoryRoot == directory.standardizedFileURL)
        #expect(snapshot?.statesByRelativePath[fileName] == .untracked)
    }

    @MainActor @Test func showsRepositoryRootFromItsParentDirectory() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("MiMiGitParent-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let repository = parent.appendingPathComponent("Repository", isDirectory: true)
        let ordinaryFolder = parent.appendingPathComponent("Ordinary", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ordinaryFolder, withIntermediateDirectories: true)
        let git = Process()
        git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        git.arguments = ["-C", repository.path, "init", "-q"]
        try git.run()
        git.waitUntilExit()
        #expect(git.terminationStatus == 0)
        let store = GitPanelStatusStore.shared
        await store.refresh(directory: parent)
        #expect(store.state(for: repository, in: parent) == .clean)
        #expect(store.repositoryRoot(for: repository, in: parent) == repository.standardizedFileURL)
        #expect(store.state(for: ordinaryFolder, in: parent) == nil)
        try Data("change".utf8).write(to: repository.appendingPathComponent("new.txt"))
        await store.refresh(directory: parent)
        #expect(store.state(for: repository, in: parent) == .untracked)
    }
}
// MARK: - Mock Remote Provider
private final class MockRemoteSearchProvider: RemoteFileProvider, @unchecked Sendable {
    let isConnected = true
    let mountPath = "sftp://kira@example.test/Users/kira"
    let entries: [String: [RemoteFileItem]]
    let download: URL?
    init(entries: [String: [RemoteFileItem]], download: URL? = nil) {
        self.entries = entries
        self.download = download
    }
    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {}
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        guard let items = entries[path] else { throw CocoaError(.fileNoSuchFile) }
        return items
    }
    @concurrent func downloadFile(remotePath: String) async throws -> URL {
        guard let download else { throw CocoaError(.fileNoSuchFile) }
        return download
    }
    @concurrent func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {}
    @concurrent func uploadToRemote(localPath: String, remotePath: String, recursive: Bool) async throws {}
    @concurrent func createFile(at remotePath: String) async throws {}
    @concurrent func createDirectory(at remotePath: String) async throws {}
    @concurrent func deleteItem(at remotePath: String, recursive: Bool) async throws {}
    @concurrent func disconnect() async {}
}

// MARK: - Remote Find Files Tests
final class RemoteFindFilesTests: XCTestCase {
    @MainActor
    func testOriginatingRemotePathSurvivesEverySearchPreset() {
        let path = "sftp://kira@example.test/Users/kira/Documents"
        let model = FindFilesViewModel()
        model.configure(searchPath: path)
        XCTAssertEqual(model.searchDirectory, path)
        model.applyLargeStaleFilesPreset()
        model.applyApplicationLeftoversPreset()
        model.applyEmptyStaleFoldersPreset()
        model.applyOldDownloadsPreset()
        model.applyOldInstallersPreset()
        model.applyTemporaryFilesPreset()
        model.applyRecentlyModifiedPreset()
        XCTAssertEqual(model.searchDirectory, path)
    }

    @MainActor
    func testFTPStalePresetUsesAvailableModificationDate() {
        let model = FindFilesViewModel()
        model.configure(searchPath: "ftp://kira@example.test/Users/kira")
        model.applyLargeStaleFilesPreset()
        XCTAssertEqual(model.advancedSettings.staleTimestampFilter, .modified)
    }

    func testRemoteSearchStaysInsideSelectedRoot() async throws {
        let root = URL(string: "sftp://kira@example.test/Users/kira/Documents")!
        let provider = MockRemoteSearchProvider(entries: [
            "/Users/kira/Documents": [
                RemoteFileItem(name: "notes.txt", path: "/Users/kira/Documents/notes.txt", isDirectory: false, size: 8),
                RemoteFileItem(name: "Projects", path: "/Users/kira/Documents/Projects", isDirectory: true),
                RemoteFileItem(name: "outside.txt", path: "/Users/kira/Other/outside.txt", isDirectory: false, size: 8)
            ],
            "/Users/kira/Documents/Projects": [
                RemoteFileItem(name: "report.txt", path: "/Users/kira/Documents/Projects/report.txt", isDirectory: false, size: 12)
            ]
        ])
        var criteria = FindFilesCriteria(searchDirectory: root)
        criteria.fileNamePattern = "*.txt"
        let results = await collect(criteria: criteria, provider: provider)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.fileURL.absoluteString.hasPrefix(root.absoluteString + "/") })
        XCTAssertTrue(results.allSatisfy { $0.filePath.hasPrefix("sftp://kira@example.test/") })
    }

    func testRemoteSearchRespectsNoSubdirectoriesAndModifiedDate() async throws {
        let root = URL(string: "sftp://kira@example.test/Users/kira")!
        let old = Date().addingTimeInterval(-120 * 86_400)
        let recent = Date()
        let provider = MockRemoteSearchProvider(entries: [
            "/Users/kira": [
                RemoteFileItem(name: "old.tmp", path: "/Users/kira/old.tmp", isDirectory: false, size: 1, modified: old),
                RemoteFileItem(name: "new.tmp", path: "/Users/kira/new.tmp", isDirectory: false, size: 1, modified: recent),
                RemoteFileItem(name: "Nested", path: "/Users/kira/Nested", isDirectory: true)
            ],
            "/Users/kira/Nested": [RemoteFileItem(name: "hidden.tmp", path: "/Users/kira/Nested/hidden.tmp", isDirectory: false, size: 1, modified: old)]
        ])
        var criteria = FindFilesCriteria(searchDirectory: root)
        criteria.fileNamePattern = "*.tmp"
        criteria.searchInSubdirectories = false
        criteria.modificationOlderThanDays = 90
        let results = await collect(criteria: criteria, provider: provider)
        XCTAssertEqual(results.map(\.fileName), ["old.tmp"])
    }

    func testRemoteCleanupUsesSelectedRoot() async throws {
        let root = URL(string: "sftp://kira@example.test/Users/kira/Documents")!
        let old = Date().addingTimeInterval(-120 * 86_400)
        let provider = MockRemoteSearchProvider(entries: [
            "/Users/kira/Documents": [
                RemoteFileItem(name: "old.tmp", path: "/Users/kira/Documents/old.tmp", isDirectory: false, modified: old),
                RemoteFileItem(name: "empty", path: "/Users/kira/Documents/empty", isDirectory: true),
                RemoteFileItem(name: "outside.tmp", path: "/Users/kira/Other/outside.tmp", isDirectory: false, modified: old)
            ],
            "/Users/kira/Documents/empty": []
        ])
        let candidates = try await RemoteCleanupScanner().scan(root: root, provider: provider) { _ in }
        XCTAssertEqual(Set(candidates.map(\.item.name)), ["old.tmp", "empty"])
        XCTAssertTrue(candidates.allSatisfy { $0.url.absoluteString.hasPrefix(root.absoluteString + "/") })
    }

    private func collect(criteria: FindFilesCriteria, provider: MockRemoteSearchProvider) async -> [FindFilesResult] {
        let collector = ResultCollector()
        let engine = RemoteFindFilesEngine()
        do {
            try await engine.search(criteria: criteria, provider: provider, passwordCallback: nil) { result in
                await collector.append(result)
            }
        } catch {
            XCTFail("Remote search failed: \(error)")
        }
        return await collector.results
    }
}

private actor ResultCollector {
    var results: [FindFilesResult] = []
    func append(_ result: FindFilesResult) { results.append(result) }
}
