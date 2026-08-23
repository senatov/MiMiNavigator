// GitStatusService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Read-only porcelain status provider with no repository mutations.

import Foundation

// MARK: - Git Status Provider
protocol GitStatusProviding: Sendable {
    func snapshot(for directory: URL) async -> GitStatusSnapshot?
}

// MARK: - Git Status Service
actor GitStatusService: GitStatusProviding {
    static let shared = GitStatusService()

    func snapshot(for directory: URL) async -> GitStatusSnapshot? {
        guard directory.isFileURL else { return nil }
        guard let rootPath = runGit(["-C", directory.path, "rev-parse", "--show-toplevel"]), !rootPath.isEmpty else { return nil }
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL
        guard let output = runGitData(["-C", rootURL.path, "status", "--porcelain=v1", "-z", "--ignored=matching", "--untracked-files=normal"]) else { return nil }
        return GitStatusSnapshot(repositoryRoot: rootURL, statesByRelativePath: parsePorcelain(output))
    }

    private func runGit(_ arguments: [String]) -> String? {
        guard let data = runGitData(arguments) else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runGitData(_ arguments: [String]) -> Data? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            log.warning("[GitStatus] command failed: \(error.localizedDescription)")
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        return output.fileHandleForReading.readDataToEndOfFile()
    }

    private func parsePorcelain(_ data: Data) -> [String: GitFileState] {
        let fields = data.split(separator: 0, omittingEmptySubsequences: true)
        var states: [String: GitFileState] = [:]
        var index = 0
        while index < fields.count {
            let field = fields[index]
            guard field.count >= 4 else {
                index += 1
                continue
            }
            let status = String(decoding: field.prefix(2), as: UTF8.self)
            let path = String(decoding: field.dropFirst(3), as: UTF8.self)
            states[path] = state(for: status)
            if status.first == "R" || status.first == "C" { index += 1 }
            index += 1
        }
        return states
    }

    private func state(for status: String) -> GitFileState {
        if status == "??" { return .untracked }
        if status == "!!" { return .ignored }
        if status.contains("U") || status == "AA" || status == "DD" { return .conflicted }
        return .modified
    }
}
