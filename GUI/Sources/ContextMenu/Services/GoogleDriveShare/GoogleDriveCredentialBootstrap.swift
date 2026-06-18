// GoogleDriveCredentialBootstrap.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bootstraps bundled Google Drive OAuth app credentials into local config.

import Foundation

// MARK: - GoogleDriveCredentialBootstrap

enum GoogleDriveCredentialBootstrap {

    // MARK: - Ensure Local Credentials

    static func ensureLocalCredentials() {
        do {
            if try hasUsableLocalCredentials() {
                log.debug("[CloudLink] Google Drive OAuth config present")
                return
            }
            guard let bundledURL = Bundle.main.url(forResource: "google_drive_oauth", withExtension: "json") else {
                log.warning("[CloudLink] bundled Google Drive OAuth config missing")
                return
            }
            let data = try Data(contentsOf: bundledURL)
            guard GoogleDriveLocalCredentials.hasClientSecret(in: data) else {
                log.error("[CloudLink] bundled Google Drive OAuth config has no client_secret")
                return
            }
            try writeLocalCredentials(data)
            log.info("[CloudLink] Google Drive OAuth config bootstrapped to \(GoogleDriveOAuthConfig.localCredentialsPath)")
        } catch {
            log.error("[CloudLink] Google Drive OAuth config bootstrap failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Local Client Secret

    static func localClientSecret() -> String {
        GoogleDriveOAuthConfig.clientSecret ?? ""
    }

    // MARK: - Save Local Client Secret

    static func saveLocalClientSecret(_ secret: String) throws {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            try deleteLocalCredentials()
            return
        }
        let payload = ["client_secret": trimmed]
        let data = try JSONEncoder().encode(payload)
        try writeLocalCredentials(data)
    }

    // MARK: - Delete Local Credentials

    static func deleteLocalCredentials() throws {
        let url = GoogleDriveOAuthConfig.localCredentialsURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Has Usable Local Credentials

    private static func hasUsableLocalCredentials() throws -> Bool {
        let url = GoogleDriveOAuthConfig.localCredentialsURL
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let data = try Data(contentsOf: url)
        return GoogleDriveLocalCredentials.hasClientSecret(in: data)
    }

    // MARK: - Write Local Credentials

    private static func writeLocalCredentials(_ data: Data) throws {
        let url = GoogleDriveOAuthConfig.localCredentialsURL
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
