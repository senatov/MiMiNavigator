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
        guard let path = ExternalToolCatalog.sevenZip.resolvedPath else {
            throw ArchiveManagerError.toolNotFound("7z not found. \(ExternalToolCatalog.sevenZip.installHint)")
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


private final class _RecentLinesBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) {
        lock.lock()
        lines.append(line)
        if lines.count > 40 {
            lines.removeFirst(lines.count - 40)
        }
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}

// MARK: - Process Runner

enum ArchiveProcessRunner {

    private static let nonFatalExitCodes: Set<Int32> = [1, 50]
    private static let timeoutSeconds: Double = 300

    private static func classifyFailure(toolName: String, exitCode: Int32, recentLines: [String]) -> ArchiveManagerError {
        let joined = recentLines.joined(separator: "\n").lowercased()

        if joined.contains("wrong password")
            || joined.contains("incorrect password")
            || joined.contains("bad password")
            || joined.contains("password is incorrect")
            || joined.contains("incorrect password supplied")
            || joined.contains("can not open encrypted archive")
        {
            return ArchiveManagerError.wrongPassword
        }

        if joined.contains("password required")
            || joined.contains("enter password")
            || joined.contains("encrypted")
            || joined.contains("cannot find password")
            || joined.contains("unable to get password")
            || joined.contains("password not supplied")
        {
            return ArchiveManagerError.passwordRequired
        }

        if joined.contains("not an archive")
            || joined.contains("unsupported archive")
            || joined.contains("can not open the file as archive")
            || joined.contains("unexpected end of archive")
            || joined.contains("end-of-central-directory signature not found")
            || joined.contains("error is not recoverable")
        {
            return ArchiveManagerError.invalidArchive("\(toolName) exit=\(exitCode)")
        }

        return ArchiveManagerError.extractionFailed("\(toolName) exit=\(exitCode)")
    }

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

        let recentLinesBuffer = _RecentLinesBuffer()

        func rememberLine(_ line: String) {
            recentLinesBuffer.append(line)
        }

        @Sendable func snapshotRecentLines() -> [String] {
            recentLinesBuffer.snapshot()
        }

        log.debug("[ProcessRunner] starting \(toolName) args=\(process.arguments?.prefix(4).joined(separator: " ") ?? "?")")

        // Read lines from a pipe in background — UTF-8 w/ Latin1 fallback
        func startLineReader(for pipe: Pipe, callback: (@Sendable (String) -> Void)?) -> Task<Void, Never> {
            Task.detached {
                let fh = pipe.fileHandleForReading
                var buffer = Data()

                func flushLine(_ lineData: Data) {
                    let line =
                        (String(data: lineData, encoding: .utf8)
                        ?? String(data: lineData, encoding: .isoLatin1)
                        ?? String(describing: lineData))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty {
                        rememberLine(line)
                        callback?(line)
                    }
                }

                while true {
                    let chunk = fh.availableData
                    if chunk.isEmpty { break }
                    buffer.append(chunk)
                    while let separatorIndex = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<separatorIndex)
                        let separator = buffer[separatorIndex]
                        let removeEnd = buffer.index(after: separatorIndex)
                        buffer.removeSubrange(buffer.startIndex..<removeEnd)

                        // Collapse CRLF into a single line break.
                        if separator == 0x0D, buffer.first == 0x0A {
                            buffer.removeFirst()
                        }

                        flushLine(lineData)
                    }
                }
                if !buffer.isEmpty {
                    flushLine(buffer)
                }
            }
        }

        // Stream both stdout AND stderr — tar outputs filenames to stdout,
        // unzip to stdout, 7z to stdout, but warnings/errors go to stderr
        var readers: [Task<Void, Never>] = []
        processHandle?.set(process)
        if let outPipe = outputPipe {
            readers.append(startLineReader(for: outPipe, callback: onLine))
        }
        // Always read stderr so failure classification works without progress UI.
        readers.append(startLineReader(for: errorPipe, callback: onLine))

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = _ResumeGate(continuation: cont)

            process.terminationHandler = { proc in
                let status = proc.terminationStatus
                log.debug("[ProcessRunner] \(toolName) exited status=\(status)")
                if status == 0 {
                    gate.resume(with: .success(()))
                } else {
                    let lines = snapshotRecentLines()
                    let classifiedError = classifyFailure(toolName: toolName, exitCode: status, recentLines: lines)
                    if Self.nonFatalExitCodes.contains(status),
                       case ArchiveManagerError.extractionFailed = classifiedError {
                        log.warning("[ProcessRunner] exit=\(status) (non-fatal)")
                        gate.resume(with: .success(()))
                        return
                    }
                    if Self.nonFatalExitCodes.contains(status) {
                        log.error("[ProcessRunner] classified non-fatal-code failure: \(classifiedError.localizedDescription)")
                    } else {
                        log.error("[ProcessRunner] classified failure: \(classifiedError.localizedDescription)")
                    }
                    gate.resume(with: .failure(classifiedError))
                }
            }

            do {
                try process.run()
                log.debug("[ProcessRunner] \(toolName) launched pid=\(process.processIdentifier)")
            } catch {
                log.error("[ProcessRunner] failed to launch \(toolName): \(error)")
                gate.resume(with: .failure(ArchiveManagerError.extractionFailed(error.localizedDescription)))
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
                                ArchiveManagerError.operationTimedOut("Timeout after \(Int(Self.timeoutSeconds))s")
                            ))
                    }
                }
        }

        readers.forEach { $0.cancel() }
        processHandle?.set(Process())
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
