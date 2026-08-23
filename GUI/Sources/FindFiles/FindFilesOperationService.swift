// FindFilesOperationService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Validates Find Files selections and executes filesystem operations outside presentation state.

import FindFilesKit
import Foundation

// MARK: - Find Files Operation Selection
enum FindFilesOperationSelection {
    // MARK: - Actionable Results
    static func actionableResults(from selected: [FindFilesResult]) -> [FindFilesResult] {
        let existing = selected.filter {
            !$0.isInsideArchive
                && !$0.isPasswordProtected
                && FileManager.default.fileExists(atPath: $0.fileURL.path)
        }
        let ordered = existing.sorted {
            $0.fileURL.standardizedFileURL.pathComponents.count
                < $1.fileURL.standardizedFileURL.pathComponents.count
        }
        var acceptedPaths: [String] = []
        return ordered.filter { result in
            let path = result.fileURL.standardizedFileURL.path
            let isNested = acceptedPaths.contains { path == $0 || path.hasPrefix($0 + "/") }
            if !isNested { acceptedPaths.append(path) }
            return !isNested
        }
    }
}

// MARK: - Find Files Operation Service
actor FindFilesOperationService {
    enum Operation: Sendable {
        case copy(destination: URL)
        case move(destination: URL)
        case trash
    }

    static let shared = FindFilesOperationService()

    // MARK: - Execute
    func execute(urls: [URL], operation: Operation) async throws {
        switch operation {
            case .copy(let destination):
                _ = try await FileOpsEngine.shared.copy(items: urls, to: destination)
            case .move(let destination):
                _ = try await FileOpsEngine.shared.move(items: urls, to: destination)
            case .trash:
                _ = try await FileOpsEngine.shared.delete(items: urls)
        }
    }
}
