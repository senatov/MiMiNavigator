// DropboxOAuthClient.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dropbox OAuth PKCE flow with Keychain refresh tokens.

import AppKit
import CryptoKit
import Foundation
import Security

// MARK: - DropboxOAuthClient

enum DropboxOAuthClient {
    private static let authEndpoint = "https://www.dropbox.com/oauth2/authorize"
    private static let tokenEndpoint = "https://api.dropboxapi.com/oauth2/token"
    @MainActor private static var cachedAccessToken: DropboxAccessToken?

    // MARK: - Access Token

    static func accessToken() async throws -> String {
        if let token = await cachedAccessToken, token.isValid {
            return token.value
        }
        if let refreshToken = try DropboxTokenStore.loadRefreshToken() {
            do {
                let token = try await refreshAccessToken(refreshToken)
                await cache(token)
                return token.value
            } catch {
                log.warning("[CloudLink] Dropbox refresh token failed: \(error.localizedDescription)")
                try? DropboxTokenStore.deleteRefreshToken(ignoreMissing: true)
            }
        }
        return try await interactiveAccessToken().value
    }

    // MARK: - Interactive Token

    private static func interactiveAccessToken() async throws -> DropboxAccessToken {
        let verifier = try randomValue(byteCount: 64)
        let state = try randomValue(byteCount: 32)
        let loopback = try DropboxOAuthLoopbackServer(expectedState: state)
        defer { loopback.cancel() }
        try await loopback.start()
        let url = try authorizationURL(verifier: verifier, state: state)
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
        let code = try await loopback.waitForCode()
        let response = try await exchangeCode(code, verifier: verifier)
        guard let refreshToken = response.refreshToken else { throw DropboxError.missingRefreshToken }
        try DropboxTokenStore.saveRefreshToken(refreshToken)
        let token = accessToken(from: response)
        await cache(token)
        return token
    }

    // MARK: - Authorization URL

    private static func authorizationURL(verifier: String, state: String) throws -> URL {
        guard var components = URLComponents(string: authEndpoint) else { throw DropboxError.invalidURL(authEndpoint) }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: DropboxOAuthConfig.appKey),
            URLQueryItem(name: "redirect_uri", value: DropboxOAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "token_access_type", value: "offline"),
            URLQueryItem(name: "scope", value: DropboxOAuthConfig.scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        guard let url = components.url else { throw DropboxError.invalidURL(authEndpoint) }
        return url
    }

    // MARK: - Token Exchange

    private static func exchangeCode(_ code: String, verifier: String) async throws -> DropboxTokenResponse {
        let values = [
            "client_id": DropboxOAuthConfig.appKey,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": DropboxOAuthConfig.redirectURI,
        ]
        return try await tokenRequest(values)
    }

    private static func refreshAccessToken(_ refreshToken: String) async throws -> DropboxAccessToken {
        let values = [
            "client_id": DropboxOAuthConfig.appKey,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ]
        return accessToken(from: try await tokenRequest(values))
    }

    private static func tokenRequest(_ values: [String: String]) async throws -> DropboxTokenResponse {
        guard let url = URL(string: tokenEndpoint) else { throw DropboxError.invalidURL(tokenEndpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(values.map { "\($0.key.dropboxFormEncoded)=\($0.value.dropboxFormEncoded)" }.sorted().joined(separator: "&").utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder().decode(DropboxTokenResponse.self, from: data)
    }

    // MARK: - PKCE

    private static func randomValue(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw DropboxError.randomBytes(status) }
        return Data(bytes).dropboxBase64URL
    }

    private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).dropboxBase64URL
    }

    // MARK: - Helpers

    private static func accessToken(from response: DropboxTokenResponse) -> DropboxAccessToken {
        DropboxAccessToken(value: response.accessToken, expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn ?? 14400)))
    }

    @MainActor
    private static func cache(_ token: DropboxAccessToken) {
        cachedAccessToken = token
    }

    private static func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw DropboxError.requestFailed(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}

// MARK: - Dropbox Encoding

private extension String {
    var dropboxFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .dropboxFormAllowed) ?? self
    }
}

private extension CharacterSet {
    static let dropboxFormAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return set
    }()
}

private extension Data {
    var dropboxBase64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
