// DuplicateService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for file duplication — delegates to Finder via AppleScript

import Foundation

// MARK: - Duplicate Service
/// Delegates file duplication to Finder (native naming: "File copy.txt", "File copy 2.txt")
@MainActor
final class DuplicateService {

    static let shared = DuplicateService()

    private init() {
        log.debug("\(#function) DuplicateService initialized")
    }

    // MARK: - Duplicate File via Finder

    /// Duplicates a file using Finder's native "duplicate" command.
    /// Finder handles naming automatically ("copy", "copy 2", etc.)
    /// Returns URL of the created duplicate.
    @discardableResult
    func duplicate(file: URL) async throws -> URL {
        log.debug("\(#function) file='\(file.lastPathComponent)' path='\(file.path)'")

        let escapedPath = file.path.replacingOccurrences(of: "\"", with: "\\\"")

        // Finder duplicate command handles naming conventions natively
        let script = """
        tell application "Finder"
            set theItem to (POSIX file "\(escapedPath)" as alias)
            set theDuplicate to duplicate theItem
            return POSIX path of (theDuplicate as alias)
        end tell
        """

        let resultPath = try executeAppleScriptReturning(script, context: "Duplicate '\(file.lastPathComponent)'")
        let duplicateURL = URL(fileURLWithPath: resultPath)

        log.info("\(#function) SUCCESS: '\(file.lastPathComponent)' → '\(duplicateURL.lastPathComponent)'")
        return duplicateURL
    }

    /// Duplicates multiple files via Finder
    func duplicate(files: [URL]) async throws -> [URL] {
        log.debug("\(#function) files.count=\(files.count)")
        var duplicates: [URL] = []
        for file in files {
            let dup = try await duplicate(file: file)
            duplicates.append(dup)
        }
        log.info("\(#function) duplicated \(duplicates.count) file(s)")
        return duplicates
    }

    // MARK: - Private

    private func executeAppleScriptReturning(_ source: String, context: String) throws -> String {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            log.error("\(#function) failed to create NSAppleScript for: \(context)")
            throw DuplicateError.scriptCreationFailed
        }

        let result = script.executeAndReturnError(&error)

        if let error = error {
            let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            log.error("\(#function) AppleScript FAILED (\(context)): \(msg)")
            throw DuplicateError.finderError(msg)
        }

        guard let path = result.stringValue, !path.isEmpty else {
            log.error("\(#function) AppleScript returned empty result for: \(context)")
            throw DuplicateError.emptyResult
        }

        return path
    }
}

// MARK: - Duplicate Errors
enum DuplicateError: LocalizedError {
    case scriptCreationFailed
    case finderError(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .scriptCreationFailed:
            return "Failed to create duplication script"
        case .finderError(let message):
            return "Finder duplication failed: \(message)"
        case .emptyResult:
            return "Finder returned no result for duplicate"
        }
    }
}
