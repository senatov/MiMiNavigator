// RemoteProviderError.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Error types for remote file providers (SFTP, FTP, SMB, AFP).

import Foundation

// MARK: - RemoteProviderError
enum RemoteProviderError: Error, LocalizedError {
    case notConnected
    case authFailed
    case notImplemented
    case invalidURL
    case listingFailed
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
            case .notConnected:
                return "Not connected to remote server"

            case .authFailed:
                return "Authentication failed"

            case .notImplemented:
                return "Operation is not implemented"

            case .invalidURL:
                return "Invalid remote URL"

            case .listingFailed:
                return "Failed to list remote directory"

            case .downloadFailed(let detail):
                return "Download failed: \(detail)"
        }
    }
}