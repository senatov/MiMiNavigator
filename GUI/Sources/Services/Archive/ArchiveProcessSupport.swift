// ArchiveProcessSupport.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Low-level CLI process utilities — run w/ progress streaming & timeout

import Foundation

// MARK: - Tool Locator

enum ArchiveToolLocator {
    static func find7z() throws -> String {
        let candidates = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw ArchiveManagerError.toolNotFound("7z not found. Install with: brew install p7zip")
        }
        return path
    }
}

// MARK: - Active Process Handle

/// Sendable handle to a running extraction process — allows cancel from UI
final class ActiveArchiveProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?

    init() { self.process = nil }

    func set(_ p: Process) {
        lock.lock()
        process = p
        lock.unlock()
    }

    func terminate() {
        lock.lock()
        let p = process
        lock.unlock()
        if let p, p.isRunning {
            log.info("[ActiveArchiveProcess] terminate() pid=\(p.processIdentifier)")
            p.terminate()
        }
    }
}

// MARK: - Process Runner

enum ArchiveProcessRunner {

    private static let nonFatalExitCodes: Set<Int32> = [1, 50]
    private static let timeoutSeconds: Double = 300

    // MARK: - Simple run (legacy)
    @concurrent static func run(_ process: Process, errorPipe: Pipe) async throws {
        try await runWithProgress(process, errorPipe: errorPipe, outputPipe: nil, onLine: nil, processHandle: nil)
    }

    // MARK: - Run with progress
    @concurrent static func runWithProgress(
        _ process: Process,
        errorPipe: Pipe,
        outputPipe: Pipe?,
        onLine: (@Sendable (String) -> Void)?,
        processHandle: ActiveArchiveProcess? = nil
    ) async throws {
        let toolName = process.executableURL?.lastPathComponent ?? "?"
        log.debug("[ProcessRunner] starting \(toolName) args=\(process.arguments?.prefix(4).joined(separator: " ") ?? "?")")

        // Read lines from a pipe in background — UTF-8 w/ Latin1 fallback
        func startLineReader(for pipe: Pipe, callback: @escaping @Sendable (String) -> Void) -> Task<Void, Never> {
            Task.detached {
                let fh = pipe.fileHandleForReading
                var buffer = Data()
                while true {
                    let chunk = fh.availableData
                    if chunk.isEmpty { break }
                    buffer.append(chunk)
                    while let range = buffer.range(of: Data([0x0A])) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                        buffer.removeSubrange(buffer.startIndex...range.lowerBound)
                        // try UTF-8 first, fallback to Latin1 (never nil)
                        let line = (String(data: lineData, encoding: .utf8)
                            ?? String(data: lineData, encoding: .isoLatin1)
                            ?? String(describing: lineData))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !line.isEmpty {
                            callback(line)
                        }
                    }
                }
                if !buffer.isEmpty {
                    let line = (String(data: buffer, encoding: .utf8)
                        ?? String(data: buffer, encoding: .isoLatin1)
                        ?? String(describing: buffer))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty {
                        callback(line)
                    }
                }
            }
        }

        // Stream both stdout AND stderr — tar outputs filenames to stdout,
        // unzip to stdout, 7z to stdout, but warnings/errors go to stderr
        var readers: [Task<Void, Never>] = []
        if let callback = onLine {
            if let outPipe = outputPipe {
                readers.append(startLineReader(for: outPipe, callback: callback))
            }
            // Also read stderr for progress (some tools put file list there)
            readers.append(startLineReader(for: errorPipe, callback: callback))
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = _ResumeGate(continuation: cont)

            process.terminationHandler = { proc in
                let status = proc.terminationStatus
                log.debug("[ProcessRunner] \(toolName) exited status=\(status)")
                if status == 0 || Self.nonFatalExitCodes.contains(status) {
                    if status != 0 {
                        log.warning("[ProcessRunner] exit=\(status) (non-fatal)")
                    }
                    gate.resume(with: .success(()))
                } else {
                    let reason = "exit=\(status)"
                    log.error("[ProcessRunner] \(reason)")
                    gate.resume(with: .failure(ArchiveManagerError.extractionFailed(reason)))
                }
            }

            do {
                try process.run()
                log.debug("[ProcessRunner] \(toolName) launched pid=\(process.processIdentifier)")
            } catch {
                log.error("[ProcessRunner] failed to launch \(toolName): \(error)")
                gate.resume(with: .failure(error))
                return
            }

            // Timeout watchdog
            DispatchQueue.global()
                .asyncAfter(deadline: .now() + Self.timeoutSeconds) {
                    if process.isRunning {
                        log.error("[ProcessRunner] TIMEOUT after \(Self.timeoutSeconds)s — killing \(toolName)")
                        process.terminate()
                        gate.resume(
                            with: .failure(
                                ArchiveManagerError.extractionFailed("Timeout after \(Int(Self.timeoutSeconds))s")
                            ))
                    }
                }
        }

        readers.forEach { $0.cancel() }
    }
}

// MARK: - Resume Gate

private final class _ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private let continuation: CheckedContinuation<Void, Error>

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Void, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        switch result {
            case .success: continuation.resume()
            case .failure(let e): continuation.resume(throwing: e)
        }
    }
}
