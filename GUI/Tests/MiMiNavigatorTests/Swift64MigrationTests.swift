// Swift64MigrationTests.swift
// MiMiNavigatorTests

import FileModelKit
import Foundation
import Testing
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
}

// MARK: - Git Status Subprocess Tests
struct GitStatusSubprocessTests {
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
}
