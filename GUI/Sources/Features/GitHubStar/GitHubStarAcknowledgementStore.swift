// GitHubStarAcknowledgementStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persists the user's GitHub-star acknowledgement as an encrypted local marker.

import CryptoKit
import Foundation
import Observation

// MARK: - GitHubStarAcknowledgementStore

@MainActor
@Observable
final class GitHubStarAcknowledgementStore {
    static let shared = GitHubStarAcknowledgementStore()
    static let repositoryURL = URL(string: "https://github.com/senatov/MiMiNavigator")!
    static let markerPath = "~/.mimi/github_star.bin"

    private static let promptDateKey = "GitHubStarPromptLastShownAt"
    private static let promptInterval: TimeInterval = 14 * 24 * 60 * 60
    private static let markerValue = "MiMiNavigator GitHub star acknowledged"
    private static let encryptionKey = SymmetricKey(
        data: SHA256.hash(data: Data("Senatov.MiMiNavigator.github-star.v1".utf8))
    )

    private(set) var isAcknowledged: Bool

    // MARK: - Initialization

    private init() {
        isAcknowledged = Self.loadAcknowledgement()
    }

    // MARK: - Auto Prompt

    var shouldAutoPrompt: Bool {
        guard !isAcknowledged else { return false }
        guard let lastShown = UserDefaults.standard.object(forKey: Self.promptDateKey) as? Date else { return true }
        return Date().timeIntervalSince(lastShown) >= Self.promptInterval
    }

    // MARK: - Record Prompt

    func recordPromptShown() {
        UserDefaults.standard.set(Date(), forKey: Self.promptDateKey)
    }

    // MARK: - Mark Acknowledged

    func markAcknowledged() -> Bool {
        do {
            try Self.saveAcknowledgement()
            isAcknowledged = true
            log.info("[GitHubStar] acknowledgement marker saved")
            return true
        } catch {
            log.error("[GitHubStar] failed to save acknowledgement marker: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Marker URL

    private static var markerURL: URL {
        URL(fileURLWithPath: NSString(string: markerPath).expandingTildeInPath)
    }

    // MARK: - Load Acknowledgement

    private static func loadAcknowledgement() -> Bool {
        do {
            let encryptedData = try Data(contentsOf: markerURL)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let data = try AES.GCM.open(sealedBox, using: encryptionKey)
            let marker = try JSONDecoder().decode(AcknowledgementMarker.self, from: data)
            return marker.value == markerValue
        } catch {
            return false
        }
    }

    // MARK: - Save Acknowledgement

    private static func saveAcknowledgement() throws {
        let marker = AcknowledgementMarker(
            value: markerValue,
            acknowledgedAt: Date(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        )
        let data = try JSONEncoder().encode(marker)
        let encryptedData = try AES.GCM.seal(data, using: encryptionKey).combined!
        let directoryURL = markerURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        try encryptedData.write(to: markerURL, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: markerURL.path)
    }
}

// MARK: - AcknowledgementMarker

private struct AcknowledgementMarker: Codable {
    let value: String
    let acknowledgedAt: Date
    let appVersion: String
}
