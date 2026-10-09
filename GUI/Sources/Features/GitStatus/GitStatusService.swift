// GitStatusService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Read-only porcelain status provider with no repository mutations.

import Foundation
import Subprocess

// MARK: - Git Status Provider
protocol GitStatusProviding: Sendable {
    func snapshot(for directory: URL) async -> GitStatusSnapshot?
}

// MARK: - Git Executable Locator
enum GitExecutableLocator {
    static func resolve(
        developerDirectory: String?,
        additionalPaths: [String] = ["/opt/homebrew/bin/git", "/usr/local/bin/git"]
    ) -> String? {
        let developerPath = developerDirectory.map { "\($0)/usr/bin/git" }
        return ([developerPath].compactMap { $0 } + additionalPaths).first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }
}

// MARK: - Git Status Service
actor GitStatusService: GitStatusProviding {
    static let shared = GitStatusService()

    func snapshot(for directory: URL) async -> GitStatusSnapshot? {
        guard directory.isFileURL else { return nil }
        guard let gitPath = await gitExecutablePath() else { return nil }
        guard let rootPath = await runGit(["-C", directory.path, "rev-parse", "--show-toplevel"], gitPath: gitPath), !rootPath.isEmpty else { return nil }
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL
        guard let output = await runGitData(["-C", rootURL.path, "status", "--porcelain=v1", "-z", "--ignored=matching", "--untracked-files=normal"], gitPath: gitPath) else { return nil }
        return GitStatusSnapshot(repositoryRoot: rootURL, statesByRelativePath: parsePorcelain(output))
    }

    // MARK: - Git Executable Path
    private func gitExecutablePath() async -> String? {
        let result = try? await Subprocess.run(.path("/usr/bin/xcode-select"), arguments: ["--print-path"], output: .string(limit: 2048))
        let developerDirectory = result?.terminationStatus.isSuccess == true
            ? result?.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        return GitExecutableLocator.resolve(developerDirectory: developerDirectory)
    }

    // MARK: - Run Git
    private func runGit(_ arguments: [String], gitPath: String) async -> String? {
        guard let data = await runGitData(arguments, gitPath: gitPath) else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Run Git Data
    private func runGitData(_ arguments: [String], gitPath: String) async -> Data? {
        do {
            let result = try await Subprocess.run(.path(.init(gitPath)), arguments: Arguments(arguments), output: .bytes(limit: .max))
            guard result.terminationStatus.isSuccess else { return nil }
            return Data(result.standardOutput)
        } catch {
            log.warning("[GitStatus] command failed: \(error.localizedDescription)")
            return nil
        }
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
            let path = String(decoding: field.dropFirst(3), as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
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
