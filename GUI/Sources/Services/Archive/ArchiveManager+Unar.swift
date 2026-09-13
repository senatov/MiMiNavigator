// ArchiveManager+Unar.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: RAR extraction through unar before the generic 7-Zip fallback.

import Foundation

// MARK: - RAR Extraction
extension ArchiveManager {
    // MARK: - Locate unar
    func findUnar() -> String? {
        let candidates = ["/opt/homebrew/bin/unar", "/usr/local/bin/unar"]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    // MARK: - Extract RAR with unar
    func extractRARWithUnar(
        executablePath: String,
        archiveURL: URL,
        to destination: URL,
        password: String?,
        onProgress: ArchiveExtractor.ProgressLine?,
        processHandle: ActiveArchiveProcess?
    ) async throws {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        var arguments = ["-f", "-D", "-o", destination.path]
        if let password, !password.isEmpty {
            arguments += ["-p", password]
        }
        arguments.append(archiveURL.path)
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = archiveToolEnvironment()
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        log.info("[ArchiveManager] extracting RAR with unar: \(archiveURL.lastPathComponent)")
        try await ArchiveProcessRunner.runWithProgress(
            process,
            errorPipe: errorPipe,
            outputPipe: outputPipe,
            onLine: onProgress,
            processHandle: processHandle
        )
    }

    // MARK: - Archive tool environment
    private func archiveToolEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        return environment
    }
}
