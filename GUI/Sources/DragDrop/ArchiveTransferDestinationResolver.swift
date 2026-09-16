// ArchiveTransferDestinationResolver.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Prevents archive-root transfers from targeting the private extraction directory.

import ArchiveKit
import FileModelKit
import Foundation

// MARK: - Archive Transfer Destination Resolver
enum ArchiveTransferDestinationResolver {
    static func resolve(
        files: [CustomFile],
        destination: URL,
        archiveStates: [ArchiveNavigationState]
    ) -> URL {
        let normalizedDestination = destination.standardizedFileURL.path
        guard !files.isEmpty else { return destination }
        for state in archiveStates {
            guard state.isInsideArchive,
                  let tempRoot = state.archiveTempDir?.standardizedFileURL,
                  let archiveParent = state.archiveParentDir?.standardizedFileURL,
                  normalizedDestination == tempRoot.path
            else { continue }
            let allSourcesAreAtArchiveRoot = files.allSatisfy {
                $0.urlValue.standardizedFileURL.deletingLastPathComponent().path == tempRoot.path
            }
            if allSourcesAreAtArchiveRoot {
                return archiveParent
            }
        }
        return destination
    }
}
