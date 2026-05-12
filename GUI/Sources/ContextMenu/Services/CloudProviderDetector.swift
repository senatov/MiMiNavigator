// CloudProviderDetector.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Detects cloud storage provider from file path.
//   Supports iCloud Drive, OneDrive, Google Drive, Dropbox.

import Foundation


// MARK: - CloudProvider

enum CloudProvider: String, Sendable {
    case iCloud   = "iCloud"
    case oneDrive = "OneDrive"
    case googleDrive = "Google Drive"
    case dropbox  = "Dropbox"

    var systemImage: String {
        switch self {
        case .iCloud:      return "icloud"
        case .oneDrive:    return "cloud"
        case .googleDrive: return "externaldrive.badge.icloud"
        case .dropbox:     return "shippingbox"
        }
    }
}


// MARK: - CloudProviderDetector

enum CloudProviderDetector {

    /// Detect cloud provider from file/directory URL. Returns nil if not in cloud storage.
    static func detect(url: URL) -> CloudProvider? {
        let path = url.path
        if path.contains("/Library/Mobile Documents/com~apple~CloudDocs") {
            return .iCloud
        }
        if path.contains("/Library/CloudStorage/") {
            if path.contains("OneDrive") { return .oneDrive }
            if path.contains("GoogleDrive") { return .googleDrive }
            if path.contains("Dropbox") { return .dropbox }
        }
        // legacy Dropbox location
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix("\(home)/Dropbox/") {
            return .dropbox
        }
        return nil
    }
}
