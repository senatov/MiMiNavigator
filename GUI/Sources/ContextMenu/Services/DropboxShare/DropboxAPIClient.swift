// DropboxAPIClient.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Creates and retrieves public Dropbox shared links.

import Foundation

// MARK: - DropboxAPIClient

struct DropboxAPIClient {
    private let accessToken: String
    private let apiRoot = "https://api.dropboxapi.com/2"

    // MARK: - Init

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    // MARK: - Shared Link

    func sharedLink(for path: String) async throws -> String {
        for attempt in 0..<8 {
            if let existing = try await existingSharedLink(for: path) {
                return existing
            }
            do {
                return try await createSharedLink(for: path)
            } catch DropboxError.requestFailed(let status, let body)
                where status == 409 && body.contains("path/not_found") && attempt < 7 {
                try await Task.sleep(for: .seconds(1))
            }
        }
        throw DropboxError.requestFailed(409, "Dropbox did not finish syncing \(path).")
    }

    // MARK: - Existing Link

    private func existingSharedLink(for path: String) async throws -> String? {
        let body: [String: Any] = ["path": path, "direct_only": true]
        let data = try await request(path: "/sharing/list_shared_links", body: body)
        return try JSONDecoder().decode(DropboxSharedLinkList.self, from: data).links.first?.url
    }

    // MARK: - Create Link

    private func createSharedLink(for path: String) async throws -> String {
        let settings: [String: Any] = [
            "access": "viewer",
            "allow_download": true,
            "audience": "public",
            "requested_visibility": "public",
        ]
        let data = try await request(path: "/sharing/create_shared_link_with_settings", body: ["path": path, "settings": settings])
        return try JSONDecoder().decode(DropboxSharedLink.self, from: data).url
    }

    // MARK: - Request

    private func request(path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(apiRoot)\(path)") else { throw DropboxError.invalidURL("\(apiRoot)\(path)") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200..<300).contains(http.statusCode) else {
            throw DropboxError.requestFailed(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
