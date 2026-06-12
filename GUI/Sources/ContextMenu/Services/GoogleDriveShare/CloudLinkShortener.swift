// CloudLinkShortener.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Creates branded short aliases for generated cloud share links.

import Foundation

// MARK: - CloudLinkShortener

enum CloudLinkShortener {
    private static let endpoint = "https://spoo.me/api/v1/shorten"
    private static let aliasPrefix = "mimiNavi_"
    private static let aliasSuffixLength = 14
    private static let aliasCharacters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    private static let maximumAttempts = 8

    // MARK: - Shorten

    static func shorten(_ link: String) async throws -> String {
        var lastError: Error?
        for attempt in 0..<maximumAttempts {
            do {
                return try await requestShortLink(link, alias: makeAlias())
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

    // MARK: - Request Short Link

    private static func requestShortLink(_ link: String, alias: String) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw CloudLinkShortenerError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["long_url": link, "alias": alias])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudLinkShortenerError.requestFailed
        }
        if http.statusCode == 201 {
            let result = try JSONDecoder().decode(CloudLinkShortenerResponse.self, from: data)
            guard result.shortURL.hasPrefix("https://spoo.me/") else {
                throw CloudLinkShortenerError.invalidResponse
            }
            return result.shortURL
        }
        let error = try? JSONDecoder().decode(CloudLinkShortenerServiceError.self, from: data)
        let message = error?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
        if http.statusCode == 409 || message.localizedCaseInsensitiveContains("alias") {
            throw CloudLinkShortenerError.aliasUnavailable
        }
        if http.statusCode == 429 || http.statusCode >= 500 {
            throw CloudLinkShortenerError.serviceUnavailable(message)
        }
        throw CloudLinkShortenerError.service(message)
    }

    // MARK: - Alias

    static func makeAlias() -> String {
        var generator = SystemRandomNumberGenerator()
        let suffix = String((0..<aliasSuffixLength).map { _ in aliasCharacters.randomElement(using: &generator) ?? "0" })
        return aliasPrefix + suffix
    }
}

// MARK: - CloudLinkShortenerResponse

private struct CloudLinkShortenerResponse: Decodable {
    let shortURL: String

    enum CodingKeys: String, CodingKey {
        case shortURL = "short_url"
    }
}

// MARK: - CloudLinkShortenerServiceError

private struct CloudLinkShortenerServiceError: Decodable {
    let message: String?
}

// MARK: - CloudLinkShortenerError

private enum CloudLinkShortenerError: LocalizedError {
    case aliasUnavailable
    case invalidResponse
    case requestFailed
    case service(String)
    case serviceUnavailable(String)

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
        case .requestFailed:
            return "The link shortener request failed."
        case .service(let message):
            return "The link shortener rejected the request: \(message)"
        case .serviceUnavailable(let message):
            return "The link shortener is temporarily unavailable: \(message)"
        }
    }
}
