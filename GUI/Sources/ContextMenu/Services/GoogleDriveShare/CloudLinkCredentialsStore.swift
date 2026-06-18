// CloudLinkCredentialsStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Local file-backed credentials for cloud Share+Link services.

import Foundation

// MARK: - CloudLinkCredentials

struct CloudLinkCredentials: Codable, Sendable {
    var googleDriveRefreshToken: String?
    var dropboxRefreshToken: String?
    var tinyURLAPIToken: String?
}

// MARK: - CloudLinkCredentialKind

enum CloudLinkCredentialKind: String, Sendable {
    case googleDriveRefreshToken
    case dropboxRefreshToken
    case tinyURLAPIToken
}

// MARK: - CloudLinkCredentialsStore

enum CloudLinkCredentialsStore {
    static let path = "~/.mimi/cloud_link_credentials.json"

    // MARK: - Store URL

    static var storeURL: URL {
        URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }

    // MARK: - Load

    static func load() throws -> CloudLinkCredentials {
        let url = storeURL
        guard FileManager.default.fileExists(atPath: url.path) else { return CloudLinkCredentials() }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CloudLinkCredentials.self, from: data)
    }

    // MARK: - Save

    static func save(_ credentials: CloudLinkCredentials) throws {
        let url = storeURL
        let data = try encoded(credentials)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    // MARK: - Token

    static func token(_ kind: CloudLinkCredentialKind) throws -> String? {
        let credentials = try load()
        switch kind {
        case .googleDriveRefreshToken:
            return normalized(credentials.googleDriveRefreshToken)
        case .dropboxRefreshToken:
            return normalized(credentials.dropboxRefreshToken)
        case .tinyURLAPIToken:
            return normalized(credentials.tinyURLAPIToken)
        }
    }

    // MARK: - Set Token

    static func setToken(_ token: String?, for kind: CloudLinkCredentialKind) throws {
        var credentials = try load()
        let value = normalized(token)
        switch kind {
        case .googleDriveRefreshToken:
            credentials.googleDriveRefreshToken = value
        case .dropboxRefreshToken:
            credentials.dropboxRefreshToken = value
        case .tinyURLAPIToken:
            credentials.tinyURLAPIToken = value
        }
        try save(credentials)
    }

    // MARK: - Encoded

    private static func encoded(_ credentials: CloudLinkCredentials) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(credentials)
    }

    // MARK: - Normalized

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else { return nil }
        return trimmed
    }
}
