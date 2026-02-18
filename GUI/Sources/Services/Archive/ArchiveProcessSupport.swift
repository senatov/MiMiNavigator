// ArchiveProcessSupport.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Low-level CLI process utilities shared by Extractor and Repacker

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
/// Async wrapper for running CLI archive tools
enum ArchiveProcessRunner {

    /// unzip exit 1 = metadata warnings (extraction succeeded)
    /// unzip exit 50 = attribute warning on /tmp (extraction succeeded)
    /// tar exit 1 = files changed during archive (non-fatal)
    private static let nonFatalExitCodes: Set<Int32> = [1, 50]

    @concurrent static func run(_ process: Process, errorPipe: Pipe) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                let status = proc.terminationStatus
                if status == 0 || Self.nonFatalExitCodes.contains(status) {
                    if status != 0 {
                        let msg = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        log.warning("[ProcessRunner] exit=\(status) (non-fatal): \(msg.prefix(200))")
                    }
                    cont.resume()
                } else {
                    let msg = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "exit=\(status)"
                    log.error("[ProcessRunner] exit=\(status): \(msg.prefix(300))")
                    cont.resume(throwing: ArchiveManagerError.extractionFailed("exit=\(status): \(msg)"))
                }
            }
            do {
                try process.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
