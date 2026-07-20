// GitHubRelease.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: GitHub Releases API model and update checker.

import Foundation

// MARK: - GitHub Release Model
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlURL: String
    let publishedAt: String
    let assets: [GitHubAsset]
    var normalizedVersion: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Codable {
    let id: Int?
    let name: String
    let browserDownloadURL: String
    let size: Int
    let digest: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case browserDownloadURL = "browser_download_url"
        case size
        case digest
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    var releaseDate: Date? {
        ISO8601DateFormatter().date(from: updatedAt ?? createdAt ?? "")
    }
}
