// GoogleDriveModels.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Google Drive sharing request and response models.

import Foundation

// MARK: - GoogleDriveOAuthConfig

enum GoogleDriveOAuthConfig {
    static let clientID = "578523584420-9ccadfen5ie000dc4o8ts5a6ur5ec6kf.apps.googleusercontent.com"
    static let scope = "https://www.googleapis.com/auth/drive.file"
    static let publicFolderName = "Public"
    static let localCredentialsPath = "~/.mimi/google_drive_oauth.json"

    // MARK: - Client Secret

    static var clientSecret: String? {
        if let value = ProcessInfo.processInfo.environment["MIMI_GOOGLE_DRIVE_CLIENT_SECRET"],
           value.isEmpty == false {
            return value
        }
        return localCredentials?.clientSecret
    }

    // MARK: - Local Credentials

    private static var localCredentials: GoogleDriveLocalCredentials? {
        let expanded = NSString(string: localCredentialsPath).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: expanded)) else { return nil }
        return try? JSONDecoder().decode(GoogleDriveLocalCredentials.self, from: data)
    }
}

// MARK: - GoogleDriveLocalCredentials

struct GoogleDriveLocalCredentials: Decodable {
    let clientSecret: String?

    enum CodingKeys: String, CodingKey {
        case installed
        case clientSecret = "client_secret"
    }

    // MARK: - Init

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let directSecret = try container.decodeIfPresent(String.self, forKey: .clientSecret) {
            clientSecret = directSecret
            return
        }
        if let installed = try container.decodeIfPresent(GoogleDriveInstalledCredentials.self, forKey: .installed) {
            clientSecret = installed.clientSecret
            return
        }
        clientSecret = nil
    }
}

// MARK: - GoogleDriveInstalledCredentials

struct GoogleDriveInstalledCredentials: Decodable {
    let clientSecret: String?

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
    }
}

// MARK: - GoogleDriveTokenResponse

struct GoogleDriveTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int?
    let refreshToken: String?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

// MARK: - GoogleDriveFileListResponse

struct GoogleDriveFileListResponse: Decodable {
    let files: [GoogleDriveFile]
}

// MARK: - GoogleDriveFile

struct GoogleDriveFile: Decodable {
    let id: String
    let name: String?
    let mimeType: String?
    let webViewLink: String?
    let webContentLink: String?
}

// MARK: - GoogleDrivePermissionResponse

struct GoogleDrivePermissionResponse: Decodable {
    let id: String?
}

// MARK: - GoogleDriveError

enum GoogleDriveError: LocalizedError {
    case invalidURL(String)
    case missingLoopbackPort
    case missingOAuthCode
    case missingUploadSession
    case missingLink(String)
    case missingClientSecret
    case requestFailed(Int, String)
    case keychain(OSStatus)
    case randomBytes(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid URL: \(value)"
        case .missingLoopbackPort:
            return "OAuth callback listener did not expose a local port."
        case .missingOAuthCode:
            return "Google OAuth callback did not include an authorization code."
        case .missingUploadSession:
            return "Google Drive did not return an upload session URL."
        case .missingLink(let fileID):
            return "Google Drive did not return a share link for \(fileID)."
        case .missingClientSecret:
            return "Google Drive OAuth client secret is missing. Put downloaded desktop OAuth JSON at ~/.mimi/google_drive_oauth.json."
        case .requestFailed(let status, let body):
            return "Google Drive request failed with HTTP \(status): \(body)"
        case .keychain(let status):
            return "Keychain operation failed with status \(status)."
        case .randomBytes(let status):
            return "Secure random generation failed with status \(status)."
        }
    }
}
