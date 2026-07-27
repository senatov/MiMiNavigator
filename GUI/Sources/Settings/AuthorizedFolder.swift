// AuthorizedFolder.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Folder permission presentation model.

// MARK: - Authorized Folder
struct AuthorizedFolder: Identifiable {
    var id: String { path }
    let path: String
    let displayName: String
    let isAccessible: Bool
}
