// CloudDriveAvailability.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Detects mounted cloud drives available for Share+Link operations.

import Foundation

// MARK: - CloudDriveAvailability

enum CloudDriveAvailability {
    // MARK: - Available Providers

    static var shareProviders: [CloudProvider] {
        var providers: [CloudProvider] = []
        if GoogleDriveMountedPaths.myDriveURL() != nil {
            providers.append(.googleDrive)
        }
        if DropboxMountedPaths.rootURL() != nil {
            providers.append(.dropbox)
        }
        return providers
    }
}

// MARK: - CloudLinkProviderAvailability
enum CloudLinkProviderAvailability {
    static let googleDriveKey = "cloudLink.provider.googleDriveEnabled"
    static let dropboxKey = "cloudLink.provider.dropboxEnabled"
    static let cloudflareR2Key = "cloudLink.provider.cloudflareR2Enabled"
    // MARK: - Enabled State
    static func isEnabled(_ provider: CloudProvider) -> Bool {
        let defaults = UserDefaults.standard
        switch provider {
        case .googleDrive:
            return defaults.object(forKey: googleDriveKey) as? Bool ?? true
        case .dropbox:
            return defaults.object(forKey: dropboxKey) as? Bool ?? true
        case .cloudflareR2:
            return defaults.object(forKey: cloudflareR2Key) as? Bool ?? false
        default:
            return true
        }
    }
}
