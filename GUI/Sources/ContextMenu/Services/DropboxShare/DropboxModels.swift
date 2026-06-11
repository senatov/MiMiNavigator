// DropboxModels.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dropbox OAuth, sharing, and error models.

import Foundation

// MARK: - DropboxOAuthConfig

enum DropboxOAuthConfig {
    static let appKey = "qso2hk6zhqw91rz"
    static let redirectURI = "http://127.0.0.1:53682/dropbox/oauth2callback"
    static let scopes = "files.metadata.read sharing.read sharing.write"
}

// MARK: - DropboxTokenResponse

struct DropboxTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int?
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

// MARK: - DropboxAccessToken

struct DropboxAccessToken: Sendable {
    let value: String
    let expiresAt: Date

    var isValid: Bool {
        Date().addingTimeInterval(60) < expiresAt
    }
}

// MARK: - DropboxSharedLink

struct DropboxSharedLink: Decodable {
    let url: String
}

// MARK: - DropboxSharedLinkList

struct DropboxSharedLinkList: Decodable {
    let links: [DropboxSharedLink]
}

// MARK: - DropboxError

enum DropboxError: LocalizedError {
    case invalidURL(String)
    case missingOAuthCode
    case missingRefreshToken
    case missingDropboxRoot
    case missingPublicFolder
    case requestFailed(Int, String)
    case keychain(OSStatus)
    case randomBytes(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid URL: \(value)"
        case .missingOAuthCode:
            return "Dropbox OAuth did not return an authorization code."
        case .missingRefreshToken:
            return "Dropbox OAuth did not return a refresh token."
        case .missingDropboxRoot:
            return "The mounted Dropbox folder was not found."
        case .missingPublicFolder:
            return "The Dropbox Public folder could not be created."
        case .requestFailed(let status, let body):
            return "Dropbox request failed with HTTP \(status): \(body)"
        case .keychain(let status):
            return "Dropbox Keychain operation failed with status \(status)."
        case .randomBytes(let status):
            return "Secure random generation failed with status \(status)."
        }
    }
}
