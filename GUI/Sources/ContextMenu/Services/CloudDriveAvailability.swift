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
