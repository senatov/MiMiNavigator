//
//  FileOpsService+Resolve.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
// Description: Validation and conflict-resolution helpers for FileOpsService.

import Foundation

// MARK: - FileOpsService + Resolve
extension FileOpsService {

    // MARK: - Validation
    func validateDestination(_ destination: URL) throws {
        guard fileManager.fileExists(atPath: destination.path) else {
            throw FileOpsError.invalidDestination(destination.path)
        }
    }

    // MARK: - Conflict Resolution
    func resolveConflict(targetURL: URL, source: URL, resolution: ConflictResolution) throws -> URL {
        switch resolution {
        case .skip:
            return targetURL

        case .keepBoth:
            return UniqueNameGenerator.generate(for: targetURL, fileManager: fileManager)

        case .replace:
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            return targetURL

        case .stop:
            throw FileOpsError.operationCancelled
        }
    }
}
