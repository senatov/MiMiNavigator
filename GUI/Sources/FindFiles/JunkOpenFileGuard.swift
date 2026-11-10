// JunkOpenFileGuard.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Darwin
import Foundation

// MARK: - Open File Guard
enum JunkOpenFileGuard {
    // MARK: - Captured Output
    private final class DataCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var value = Data()
        // MARK: - Store Captured Output
        func store(_ data: Data) { lock.lock(); value = data; lock.unlock() }
        // MARK: - Read Captured Output
        func load() -> Data { lock.lock(); defer { lock.unlock() }; return value }
    }

    struct Holder: Sendable {
        let process: String
        let path: String
    }

    enum Result: Sendable {
        case free
        case inUse([Holder])
        case unavailable
    }

    // MARK: - Check Selected Paths
    static func check(_ urls: [URL]) async -> Result {
        await Task.detached(priority: .utility) { checkSynchronously(urls) }.value
    }

    // MARK: - Run Bounded Open File Listing
    private static func checkSynchronously(_ urls: [URL]) -> Result {
        let output = Pipe()
        let capture = DataCapture()
        let outputRead = DispatchSemaphore(value: 0)
        let process = Process()
        let terminated = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-n", "-P", "-w", "-F", "pcn", "-u", String(getuid())]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in terminated.signal() }
        do { try process.run() } catch { return .unavailable }
        DispatchQueue.global(qos: .utility).async {
            capture.store(output.fileHandleForReading.readDataToEndOfFile())
            outputRead.signal()
        }
        let timedOut = terminated.wait(timeout: .now() + 12) == .timedOut
        if timedOut {
            if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
            _ = terminated.wait(timeout: .now() + 2)
        }
        guard outputRead.wait(timeout: .now() + 2) == .success,
              !timedOut, process.terminationStatus == 0,
              let listing = String(data: capture.load(), encoding: .utf8) else { return .unavailable }
        let prefixes = Set(urls.flatMap(pathSpellings))
        let holders = holders(in: listing, selectedPaths: prefixes)
        return holders.isEmpty ? .free : .inUse(holders)
    }

    // MARK: - Match Open Paths
    private static func holders(in listing: String, selectedPaths: Set<String>) -> [Holder] {
        var result: [Holder] = []
        var pid = ""
        var command = ""
        for line in listing.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())
            switch field {
            case "p": pid = value
            case "c": command = value
            case "n":
                let normalized = URL(fileURLWithPath: value).standardizedFileURL.path
                if selectedPaths.contains(where: { normalized == $0 || normalized.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }) {
                    result.append(Holder(process: "\(command) (pid \(pid))", path: normalized))
                }
            default: continue
            }
        }
        var seen = Set<String>()
        return result.filter { seen.insert("\($0.process)|\($0.path)").inserted }.prefix(8).map { $0 }
    }

    // MARK: - Resolve Selected Path Spellings
    private static func pathSpellings(_ url: URL) -> [String] {
        let standardized = url.standardizedFileURL
        var paths = [standardized.path, standardized.resolvingSymlinksInPath().path]
        if let resolved = realpath(standardized.path, nil) {
            paths.append(String(cString: resolved))
            free(resolved)
        }
        return paths
    }
}
