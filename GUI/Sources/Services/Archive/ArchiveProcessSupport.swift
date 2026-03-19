// ArchiveProcessSupport.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Low-level CLI process utilities — run w/ progress streaming & timeout

import Foundation

// MARK: - Tool Locator
/// Resolves paths to optional CLI tools (7z, etc.)
enum ArchiveToolLocator {

    static func find7z() throws -> String {
        let candidates = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw ArchiveManagerError.toolNotFound("7z not found. Install with: brew install p7zip")
        }
        return path
    }
}

// MARK: - Process Runner
/// Async wrapper for running CLI archive tools with optional stdout streaming
enum ArchiveProcessRunner {

    /// unzip exit 1 = metadata warnings (extraction succeeded)
    /// unzip exit 50 = attribute warning on /tmp (extraction succeeded)
    /// tar exit 1 = files changed during archive (non-fatal)
    private static let nonFatalExitCodes: Set<Int32> = [1, 50]

    /// Timeout for extraction process (5 min default)
    private static let timeoutSeconds: Double = 300

    // MARK: - Simple run (legacy compat)

    @concurrent static func run(_ process: Process, errorPipe: Pipe) async throws {
        try await runWithProgress(process, errorPipe: errorPipe, outputPipe: nil, onLine: nil)
    }

    // MARK: - Run with progress streaming

    @concurrent static func runWithProgress(
        _ process: Process,
        errorPipe: Pipe,
        outputPipe: Pipe?,
        onLine: (@Sendable (String) -> Void)?
    ) async throws {
        let toolName = process.executableURL?.lastPathComponent ?? "?"
        log.debug("[ProcessRunner] starting \(toolName) args=\(process.arguments?.prefix(4).joined(separator: " ") ?? "?")")

        // Stream stdout lines in bg if callback provided
        let lineReader: Task<Void, Never>? = if let outPipe = outputPipe, let callback = onLine {
            Task.detached {
                let fh = outPipe.fileHandleForReading
                var buffer = Data()
                while true {
                    let chunk = fh.availableData
                    if chunk.isEmpty { break }
                    buffer.append(chunk)
                    // split on newlines
                    while let range = buffer.range(of: Data([0x0A])) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                        buffer.removeSubrange(buffer.startIndex...range.lowerBound)
                        if let line = String(data: lineData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !line.isEmpty {
                            callback(line)
                        }
                    }
                }
                // flush remainder
                if !buffer.isEmpty,
                   let line = String(data: buffer, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !line.isEmpty {
                    callback(line)
                }
            }
        } else {
            nil
        }

        // If no progress callback, just sink stdout
        if outputPipe != nil && onLine == nil {
            // already assigned to process — let it drain
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var resumed = false
            let lock = NSLock()
            func resumeOnce(with result: Result<Void, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                switch result {
                case .success: cont.resume()
                case .failure(let e): cont.resume(throwing: e)
                }
            }

            process.terminationHandler = { proc in
                let status = proc.terminationStatus
                log.debug("[ProcessRunner] \(toolName) exited status=\(status)")
                if status == 0 || Self.nonFatalExitCodes.contains(status) {
                    if status != 0 {
                        let msg = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        log.warning("[ProcessRunner] exit=\(status) (non-fatal): \(msg.prefix(200))")
                    }
                    resumeOnce(with: .success(()))
                } else {
                    let msg = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "exit=\(status)"
                    log.error("[ProcessRunner] exit=\(status): \(msg.prefix(300))")
                    resumeOnce(with: .failure(ArchiveManagerError.extractionFailed("exit=\(status): \(msg)")))
                }
            }

            do {
                try process.run()
                log.debug("[ProcessRunner] \(toolName) launched pid=\(process.processIdentifier)")
            } catch {
                log.error("[ProcessRunner] failed to launch \(toolName): \(error)")
                resumeOnce(with: .failure(error))
            }

            // Timeout watchdog
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.timeoutSeconds) {
                lock.lock()
                let wasResumed = resumed
                lock.unlock()
                if !wasResumed && process.isRunning {
                    log.error("[ProcessRunner] TIMEOUT after \(Self.timeoutSeconds)s — killing \(toolName)")
                    process.terminate()
                    resumeOnce(with: .failure(
                        ArchiveManagerError.extractionFailed("Timeout after \(Int(Self.timeoutSeconds))s")
                    ))
                }
            }
        }

        lineReader?.cancel()
    }
}
