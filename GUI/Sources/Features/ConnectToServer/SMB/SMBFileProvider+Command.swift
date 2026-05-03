//
//  SMBFileProvider+Command.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 04.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Darwin
import Foundation

// MARK: - SMB Command Runner
extension SMBFileProvider {

    struct CommandResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String

        var combinedOutput: String {
            let parts = [
                stdout.trimmingCharacters(in: .whitespacesAndNewlines), stderr.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
            .filter { !$0.isEmpty }
            return parts.joined(separator: " | ")
        }
    }

    private enum ProcessWaitResult {
        case completed
        case cancelled
        case timedOut
    }

    @discardableResult
    static func runCommand(
        executable: String,
        arguments: [String],
        redactedArguments: [String],
        ignoreNonZeroExitCode: Bool = false,
        timeout: TimeInterval = defaultCommandTimeout
    ) throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        log.debug("[SMB] run \(executable) args=\(redactedArguments.joined(separator: " "))")
        try process.run()
        let waitResult = waitForProcess(process, timeout: timeout)
        if waitResult != .completed {
            terminateProcess(process)
            let stdout = readPipe(stdoutPipe)
            let stderr = readPipe(stderrPipe)
            let message = timeoutMessage(for: waitResult, timeout: timeout, redactedArguments: redactedArguments)
            log.warning("[SMB] command stopped \(message)")
            throw SMBProviderError.commandFailed([message, stdout, stderr].filter { !$0.isEmpty }.joined(separator: " | "))
        }
        let stdout = readPipe(stdoutPipe)
        let stderr = readPipe(stderrPipe)
        let result = CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
        if !ignoreNonZeroExitCode, result.exitCode != 0 {
            log.warning("[SMB] command failed exit=\(result.exitCode) output='\(result.combinedOutput)'")
            throw SMBProviderError.commandFailed(result.combinedOutput)
        }
        return result
    }

    // MARK: - Process Timeout
    private static func waitForProcess(_ process: Process, timeout: TimeInterval) -> ProcessWaitResult {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if isCurrentTaskCancelled() {
                return .cancelled
            }
            if Date() >= deadline {
                return .timedOut
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return .completed
    }

    // MARK: - Cancellation Check
    private static func isCurrentTaskCancelled() -> Bool {
        withUnsafeCurrentTask { task in
            task?.isCancelled ?? false
        }
    }

    // MARK: - Timeout Message
    private static func timeoutMessage(for result: ProcessWaitResult, timeout: TimeInterval, redactedArguments: [String]) -> String {
        let command = redactedArguments.joined(separator: " ")
        switch result {
        case .completed:
            return command
        case .cancelled:
            return "Cancelled: \(command)"
        case .timedOut:
            return "Timed out after \(Int(timeout))s: \(command)"
        }
    }

    // MARK: - Process Termination
    private static func terminateProcess(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        if waitForProcess(process, timeout: 2) == .completed {
            return
        }
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
    }

    // MARK: - Pipe Read
    private static func readPipe(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
