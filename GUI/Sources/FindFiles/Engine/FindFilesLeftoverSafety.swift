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

    static var searchDirectories: [URL] {
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        return [
            "Application Support",
            "Caches",
            "Preferences",
            "Logs",
            "Saved Application State",
            "LaunchAgents"
        ].map { library.appendingPathComponent($0, isDirectory: true) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func installedApplicationIdentities() -> Set<String> {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]
        var identities = Set<String>()
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                identities.insert(normalized(url.deletingPathExtension().lastPathComponent))
                if let identifier = Bundle(url: url)?.bundleIdentifier {
                    identities.insert(identifier.lowercased())
                }
                enumerator.skipDescendants()
            }
        }
        return identities
    }

    static func isCandidate(_ url: URL, installedIdentities: Set<String>) -> Bool {
        let name = url.lastPathComponent
        let lowercaseName = name.lowercased()
        guard !lowercaseName.hasPrefix("."),
              !lowercaseName.hasPrefix("com.apple."),
              !lowercaseName.hasPrefix("group.com.apple."),
              !protectedNames.contains(name)
        else { return false }
        let stem = removingKnownSuffixes(from: name)
        let rawKey = stem.lowercased()
        let normalizedKey = normalized(stem)
        guard !installedIdentities.contains(rawKey),
              !installedIdentities.contains(normalizedKey)
        else { return false }
        guard normalizedKey.count >= 4 else { return true }
        return !installedIdentities.contains {
            let normalizedIdentity = normalized($0)
            return normalizedIdentity.contains(normalizedKey) || normalizedKey.contains(normalizedIdentity)
        }
    }

    private static func removingKnownSuffixes(from name: String) -> String {
        let suffixes = [".savedstate", ".plist", ".log"]
        let lowercaseName = name.lowercased()
        guard let suffix = suffixes.first(where: { lowercaseName.hasSuffix($0) }) else {
            return name
        }
        return String(name.dropLast(suffix.count))
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().filter(\.isLetter)
    }
}
