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
    // MARK: - Run asynchronously with bounded diagnostics
    @discardableResult
    func runProcess(
        executablePath: String,
        arguments: [String],
        panel: ProgressPanel,
        outputFile: URL? = nil
    ) async throws -> String {
        guard phase != .cancelled else { throw CancellationError() }
        let fileOutput: FileHandle?
        if let outputFile {
            FileManager.default.createFile(atPath: outputFile.path, contents: nil)
            fileOutput = try FileHandle(forWritingTo: outputFile)
        } else {
            fileOutput = nil
        }
        defer { try? fileOutput?.close() }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let process = makeProcess(executablePath: executablePath, arguments: arguments)
            let stderr = Pipe()
            let stdout = Pipe()
            let diagnosticID = UUID().uuidString
            let errorOutput = MediaProcessOutput()
            let standardOutput = MediaProcessOutput()
            let started = ContinuousClock.now
            configureProcess(process, stderr: stderr, stdout: stdout)
            if let fileOutput {
                process.standardOutput = fileOutput
                try? stdout.fileHandleForWriting.close()
            }
            installReadabilityHandler(for: stderr.fileHandleForReading, panel: panel, process: process, output: errorOutput)
            installReadabilityHandler(for: stdout.fileHandleForReading, panel: panel, process: process, output: standardOutput)
            let watchdog = Task { @MainActor in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    guard process.isRunning else { return }
                    log.warning("[MediaProcess] id=\(diagnosticID) still-running pid=\(process.processIdentifier) elapsed=\(started.duration(to: .now)) stderrBytes=\(errorOutput.snapshot().bytes) stdoutBytes=\(standardOutput.snapshot().bytes)")
                }
            }
            installTerminationHandler(
                for: process,
                stderrHandle: stderr.fileHandleForReading,
                stdoutHandle: stdout.fileHandleForReading,
                errorOutput: errorOutput,
                standardOutput: standardOutput,
                diagnosticID: diagnosticID,
                started: started,
                watchdog: watchdog,
                continuation: continuation
            )
            do {
                activeProcess = process
                try process.run()
                log.info("[MediaProcess] id=\(diagnosticID) launched pid=\(process.processIdentifier) executable=\(executablePath.debugDescription) args=\(arguments)")
                appendLaunchCommand(executablePath: executablePath, arguments: arguments, panel: panel)
            } catch {
                watchdog.cancel()
                log.error("[MediaProcess] id=\(diagnosticID) launch-failed error=\(error.localizedDescription)")
                cleanupAfterLaunchFailure(
                    stderrHandle: stderr.fileHandleForReading,
                    stdoutHandle: stdout.fileHandleForReading,
                    error: error,
                    continuation: continuation
                )
            }
        }
    }

    func makeProcess(executablePath: String, arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment
        process.standardInput = FileHandle.nullDevice
        return process
    }

    func configureProcess(_ process: Process, stderr: Pipe, stdout: Pipe) {
        process.standardError = stderr
        process.standardOutput = stdout
    }

    func installReadabilityHandler(for handle: FileHandle, panel: ProgressPanel, process: Process, output: MediaProcessOutput) {
        handle.readabilityHandler = { fileHandle in
            let chunk = output.read(fileHandle)
            guard !chunk.isEmpty else {
                fileHandle.readabilityHandler = nil
                return
            }
            Task { @MainActor in
                guard self.activeProcess === process else { return }
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
        stderrHandle: FileHandle,
        stdoutHandle: FileHandle,
        errorOutput: MediaProcessOutput,
        standardOutput: MediaProcessOutput,
        diagnosticID: String,
        started: ContinuousClock.Instant,
        watchdog: Task<Void, Never>,
        continuation: CheckedContinuation<String, Error>
    ) {
        process.terminationHandler = { process in
            stderrHandle.readabilityHandler = nil
            stdoutHandle.readabilityHandler = nil
            _ = errorOutput.read(stderrHandle, toEnd: true)
            _ = standardOutput.read(stdoutHandle, toEnd: true)
            let capturedError = errorOutput.snapshot()
            let capturedOutput = standardOutput.snapshot()
            log.info("[MediaProcess] id=\(diagnosticID) exited pid=\(process.processIdentifier) code=\(process.terminationStatus) reason=\(process.terminationReason.rawValue) elapsed=\(started.duration(to: .now)) stderrBytes=\(capturedError.bytes) stdoutBytes=\(capturedOutput.bytes)")
            if process.terminationStatus != 0 {
                log.error("[MediaProcess] id=\(diagnosticID) stderrTail=\(capturedError.text.debugDescription) stdoutTail=\(capturedOutput.text.debugDescription)")
            }
            Task { @MainActor in
                watchdog.cancel()
                if self.activeProcess === process { self.activeProcess = nil }
                if process.terminationReason == .uncaughtSignal,
                    process.terminationStatus == SIGTERM {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if process.terminationStatus == 0 {
                    continuation.resume(returning: capturedOutput.text + capturedError.text)
                    return
                }
                continuation.resume(
                    throwing: ConversionError.processDiagnostic(
                        Int(process.terminationStatus),
                        String(capturedError.text.trimmingCharacters(in: .whitespacesAndNewlines).suffix(600)))
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
        stderrHandle: FileHandle,
        stdoutHandle: FileHandle,
        error: Error,
        continuation: CheckedContinuation<String, Error>
    ) {
        stderrHandle.readabilityHandler = nil
        stdoutHandle.readabilityHandler = nil
        activeProcess = nil
        continuation.resume(throwing: error)
    }
}
