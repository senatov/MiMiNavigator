// CloudLinkShortener.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Creates branded short aliases for generated cloud share links.

import Foundation

// MARK: - CloudLinkShortener

enum CloudLinkShortener {
    private static let endpoint = "https://is.gd/create.php"
    private static let aliasPrefix = "MiMiNavi_"
    private static let maximumAttempts = 4

    // MARK: - Shorten

    static func shorten(_ link: String) async throws -> String {
        var lastError: Error?
        for _ in 0..<maximumAttempts {
            do {
                return try await requestShortLink(link, alias: makeAlias())
            } catch CloudLinkShortenerError.aliasUnavailable {
                lastError = CloudLinkShortenerError.aliasUnavailable
            } catch {
                throw error
            }
        }
        throw lastError ?? CloudLinkShortenerError.invalidResponse
    }

    // MARK: - Request Short Link

    private static func requestShortLink(_ link: String, alias: String) async throws -> String {
        guard var components = URLComponents(string: endpoint) else {
            throw CloudLinkShortenerError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "url", value: link),
            URLQueryItem(name: "shorturl", value: alias),
        ]
        guard let url = components.url else {
            throw CloudLinkShortenerError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard response is HTTPURLResponse else {
            throw CloudLinkShortenerError.requestFailed
        }
        let result = try JSONDecoder().decode(CloudLinkShortenerResponse.self, from: data)
        if let shortURL = result.shortURL, shortURL.isEmpty == false {
            return shortURL
        }
        if result.errorCode == 2 {
            throw CloudLinkShortenerError.aliasUnavailable
        }
        throw CloudLinkShortenerError.service(result.errorMessage ?? "Unknown error")
    }

    // MARK: - Alias

    private static func makeAlias() -> String {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)
        return aliasPrefix + suffix
    }
}

// MARK: - CloudLinkShortenerResponse

private struct CloudLinkShortenerResponse: Decodable {
    let shortURL: String?
    let errorCode: Int?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case shortURL = "shorturl"
        case errorCode = "errorcode"
        case errorMessage = "errormessage"
    }
}

// MARK: - CloudLinkShortenerError

private enum CloudLinkShortenerError: LocalizedError {
    case aliasUnavailable
    case invalidResponse
    case requestFailed
    case service(String)

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
        }
    }
}
