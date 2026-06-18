// CloudLinkShortener.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Creates branded short aliases for generated cloud share links.

import Foundation
import FileModelKit

// MARK: - CloudLinkShortener

enum CloudLinkShortener {
    private static let endpoint = "https://api.tinyurl.com/create"
    private static let shortURLPrefix = "https://tinyurl.com/"
    private static let aliasPrefix = "mimiNavi"
    private static let aliasSuffixLength = 8
    private static let aliasCharacters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    private static let maximumAttempts = 8

    // MARK: - Shorten

    static func shorten(_ link: String) async throws -> String {
        let token = try tinyURLAPIToken()
        var lastError: Error?
        for attempt in 0..<maximumAttempts {
            do {
                return try await requestShortLink(link, alias: makeAlias(), token: token)
            } catch let error as CloudLinkShortenerError where error.isRetryable {
                lastError = error
                if attempt < maximumAttempts - 1 {
                    try await Task.sleep(for: .milliseconds(500))
                }
            } catch {
                throw error
            }
        }
        throw lastError ?? CloudLinkShortenerError.invalidResponse
    }

    // MARK: - TinyURL API Token

    private static func tinyURLAPIToken() throws -> String {
        if let token = try? TinyURLTokenStore.loadAPIToken(), !token.isEmpty {
            return token
        }
        let bundledToken = CloudShortLinkTokenProvider.tinyURLAPIToken
        guard !bundledToken.isEmpty else {
            throw CloudLinkShortenerError.missingAPIToken
        }
        return bundledToken
    }

    // MARK: - Request Short Link

    private static func requestShortLink(_ link: String, alias: String, token: String) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw CloudLinkShortenerError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(TinyURLCreateRequest(url: link, alias: alias))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudLinkShortenerError.requestFailed
        }
        if http.statusCode == 200 || http.statusCode == 201 {
            return try decodeShortURL(from: data)
        }
        throw serviceError(from: data, statusCode: http.statusCode)
    }

    // MARK: - Decode Short URL

    private static func decodeShortURL(from data: Data) throws -> String {
        let result = try JSONDecoder().decode(TinyURLCreateResponse.self, from: data)
        guard let shortURL = result.shortURL, shortURL.hasPrefix(shortURLPrefix) else {
            throw CloudLinkShortenerError.invalidResponse
        }
        return shortURL
    }

    // MARK: - Service Error

    private static func serviceError(from data: Data, statusCode: Int) -> CloudLinkShortenerError {
        let serviceError = try? JSONDecoder().decode(TinyURLServiceError.self, from: data)
        let message = serviceError?.detail ?? String(data: data, encoding: .utf8) ?? "Unknown error"
        if statusCode == 409 || message.localizedCaseInsensitiveContains("alias") {
            return .aliasUnavailable
        }
        if statusCode == 401 || statusCode == 403 {
            return .unauthorized
        }
        if statusCode == 429 || statusCode >= 500 {
            return .serviceUnavailable(message)
        }
        return .service(message)
    }

    // MARK: - Alias

    static func makeAlias() -> String {
        var generator = SystemRandomNumberGenerator()
        let suffix = String((0..<aliasSuffixLength).map { _ in aliasCharacters.randomElement(using: &generator) ?? "0" })
        return aliasPrefix + suffix
    }
}

// MARK: - TinyURLCreateRequest

private struct TinyURLCreateRequest: Encodable {
    let url: String
    let domain = "tinyurl.com"
    let alias: String
}

// MARK: - TinyURLCreateResponse

private struct TinyURLCreateResponse: Decodable {
    let data: TinyURLResponseData?

    var shortURL: String? {
        data?.tinyURL
    }
}

// MARK: - TinyURLResponseData

private struct TinyURLResponseData: Decodable {
    let tinyURL: String?

    enum CodingKeys: String, CodingKey {
        case tinyURL = "tiny_url"
    }
}

// MARK: - TinyURLServiceError

private struct TinyURLServiceError: Decodable {
    let errors: [String]?
    let message: String?
    let error: String?

    var detail: String? {
        errors?.joined(separator: ", ") ?? error ?? message
    }
}

// MARK: - CloudLinkShortenerError

private enum CloudLinkShortenerError: LocalizedError {
    case aliasUnavailable
    case invalidResponse
    case missingAPIToken
    case requestFailed
    case service(String)
    case serviceUnavailable(String)
    case unauthorized

    var isRetryable: Bool {
        switch self {
        case .aliasUnavailable, .serviceUnavailable:
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .aliasUnavailable:
            return "The generated short link alias is already in use."
        case .invalidResponse:
            return "The link shortener returned an invalid response."
        case .missingAPIToken:
            return "TinyURL API token is missing from local credentials."
        case .requestFailed:
            return "The link shortener request failed."
        case .service(let message):
            return "The link shortener rejected the request: \(message)"
        case .serviceUnavailable(let message):
            return "The link shortener is temporarily unavailable: \(message)"
        case .unauthorized:
            return "TinyURL API token was rejected."
        }
    }
}
