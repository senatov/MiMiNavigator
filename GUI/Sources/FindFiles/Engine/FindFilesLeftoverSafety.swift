// FindFilesLeftoverSafety.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Safety exclusions for application-leftover candidates.

import Foundation

// MARK: - Application Leftover Safety
enum FindFilesLeftoverSafety {
    private static let protectedNames: Set<String> = [
        "CallHistoryTransactions",
        "DifferentialPrivacy",
        "DiskImages",
        "FaceTime",
        "iCloud",
        "Knowledge",
        "networkserviceproxy"
    ]

    static func isProtectedAppSupportItem(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix("com.apple.") || protectedNames.contains(name)
    }
}
