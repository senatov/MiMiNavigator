// GoogleDriveOAuthClient.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Google OAuth desktop flow with PKCE and Keychain refresh tokens.

import AppKit
import CryptoKit
import Foundation
import Security

// MARK: - GoogleDriveOAuthClient

enum GoogleDriveOAuthClient {
    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    // MARK: - Access Token

    static func accessToken() async throws -> String {
        if let refreshToken = try GoogleDriveTokenStore.loadRefreshToken() {
            do {
                return try await refreshAccessToken(refreshToken)
            } catch {
                log.warning("[CloudLink] Google Drive refresh token failed: \(error.localizedDescription)")
                try? GoogleDriveTokenStore.deleteRefreshToken(ignoreMissing: true)
            }
        }
        return try await interactiveAccessToken()
    }

    // MARK: - Interactive Access Token

    private static func interactiveAccessToken() async throws -> String {
        guard GoogleDriveOAuthConfig.clientSecret != nil else { throw GoogleDriveError.missingClientSecret }
        let loopback = try GoogleDriveOAuthLoopbackServer()
        try await loopback.start()
        let verifier = try makeCodeVerifier()
        let challenge = codeChallenge(for: verifier)
        let authURL = try authorizationURL(redirectURI: loopback.redirectURI, challenge: challenge)
        await MainActor.run {
            _ = NSWorkspace.shared.open(authURL)
        }
        let code = try await loopback.waitForCode()
        loopback.cancel()
        let token = try await exchangeCode(code, verifier: verifier, redirectURI: loopback.redirectURI)
        if let refreshToken = token.refreshToken {
            try GoogleDriveTokenStore.saveRefreshToken(refreshToken)
        }
        return token.accessToken
    }

    // MARK: - Authorization URL

    private static func authorizationURL(redirectURI: String, challenge: String) throws -> URL {
        guard var components = URLComponents(string: authEndpoint) else { throw GoogleDriveError.invalidURL(authEndpoint) }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleDriveOAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleDriveOAuthConfig.scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let url = components.url else { throw GoogleDriveError.invalidURL(authEndpoint) }
        return url
    }

    // MARK: - Exchange Code

    private static func exchangeCode(_ code: String, verifier: String, redirectURI: String) async throws -> GoogleDriveTokenResponse {
        var values = [
            "client_id": GoogleDriveOAuthConfig.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ]
        if let clientSecret = GoogleDriveOAuthConfig.clientSecret {
            values["client_secret"] = clientSecret
        }
        let body = formBody(values)
        return try await tokenRequest(body: body)
    }

    // MARK: - Refresh Token

    private static func refreshAccessToken(_ refreshToken: String) async throws -> String {
        var values = [
            "client_id": GoogleDriveOAuthConfig.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ]
        if let clientSecret = GoogleDriveOAuthConfig.clientSecret {
            values["client_secret"] = clientSecret
        }
        let body = formBody(values)
        return try await tokenRequest(body: body).accessToken
    }

    // MARK: - Token Request

    private static func tokenRequest(body: Data) async throws -> GoogleDriveTokenResponse {
        guard let url = URL(string: tokenEndpoint) else { throw GoogleDriveError.invalidURL(tokenEndpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder().decode(GoogleDriveTokenResponse.self, from: data)
    }

    // MARK: - Form Body

    private static func formBody(_ values: [String: String]) -> Data {
        let body = values
            .map { "\($0.key.urlFormEncoded)=\($0.value.urlFormEncoded)" }
            .sorted()
            .joined(separator: "&")
        return Data(body.utf8)
    }

    // MARK: - Code Verifier

    private static func makeCodeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw GoogleDriveError.randomBytes(status) }
        return Data(bytes).base64URLEncodedString()
    }

    // MARK: - Code Challenge

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    // MARK: - Validate

    private static func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 400 && body.contains("client_secret is missing") {
                throw GoogleDriveError.missingClientSecret
            }
            throw GoogleDriveError.requestFailed(http.statusCode, body)
        }
    }
}

// MARK: - URL Form Encoding

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .googleDriveFormAllowed) ?? self
    }
}

// MARK: - Google Drive Form Character Set

private extension CharacterSet {
    static let googleDriveFormAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return set
    }()
}

// MARK: - Base64 URL Encoding

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
