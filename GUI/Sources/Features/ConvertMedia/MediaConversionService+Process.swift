// MediaConversionService+Process.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Process runner for media conversion command-line tools.

import Foundation

// MARK: - Process Runner

@MainActor
extension MediaConversionService {
    func runProcess(
        executablePath: String,
        arguments: [String],
        panel: ProgressPanel
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = makeProcess(executablePath: executablePath, arguments: arguments)
            let stderr = Pipe()
            let stdout = Pipe()
            configureProcess(process, stderr: stderr, stdout: stdout)
            installReadabilityHandler(for: stderr.fileHandleForReading, panel: panel)
            installTerminationHandler(for: process, handle: stderr.fileHandleForReading, continuation: continuation)
            do {
                activeProcess = process
                try process.run()
                appendLaunchCommand(executablePath: executablePath, arguments: arguments, panel: panel)
            } catch {
                cleanupAfterLaunchFailure(handle: stderr.fileHandleForReading, error: error, continuation: continuation)
            }
        }
    }

    func makeProcess(executablePath: String, arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment
        return process
    }

    func configureProcess(_ process: Process, stderr: Pipe, stdout: Pipe) {
        process.standardError = stderr
        process.standardOutput = stdout
    }

    func installReadabilityHandler(for handle: FileHandle, panel: ProgressPanel) {
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty,
                let chunk = String(data: data, encoding: .utf8)
            else {
                return
            }
            Task { @MainActor in
                self.appendProcessOutput(chunk, panel: panel)
            }
        }
    }

    func appendProcessOutput(_ chunk: String, panel: ProgressPanel) {
        for line in chunk.split(separator: "\n") {
            panel.appendLine(String(line))
        }
    }

    func installTerminationHandler(
        for process: Process,
        handle: FileHandle,
        continuation: CheckedContinuation<Void, Error>
    ) {
        process.terminationHandler = { process in
            handle.readabilityHandler = nil
            Task { @MainActor in
                self.activeProcess = nil
                if process.terminationReason == .uncaughtSignal,
                    process.terminationStatus == SIGTERM {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if process.terminationStatus == 0 {
                    continuation.resume()
                    return
                }
                continuation.resume(
                    throwing: ConversionError.processFailed(Int(process.terminationStatus))
                )
            }
        }
    }

    func appendLaunchCommand(
        executablePath: String,
        arguments: [String],
        panel: ProgressPanel
    ) {
        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
        let commandLine = arguments.joined(separator: " ")
        panel.appendLine("⚙ \(executableName) \(commandLine)")
    }

    func cleanupAfterLaunchFailure(
        handle: FileHandle,
        error: Error,
        continuation: CheckedContinuation<Void, Error>
    ) {
        handle.readabilityHandler = nil
        activeProcess = nil
        continuation.resume(throwing: error)
    }
}
