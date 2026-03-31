// AppInfo.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Application info for "Open With" context menu — name, icon, bundle ID.

import AppKit
import Foundation

// MARK: - Application Info

/// Represents an application that can open a file.
struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let icon: NSImage
    let url: URL
    let isDefault: Bool

    init(
        id: String? = nil,
        name: String,
        bundleIdentifier: String,
        icon: NSImage,
        url: URL,
        isDefault: Bool
    ) {
        self.id = id ?? Self.makeStableID(url: url, bundleIdentifier: bundleIdentifier)
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.url = url
        self.isDefault = isDefault
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

private extension AppInfo {
    static func makeStableID(url: URL, bundleIdentifier: String) -> String {
        let normalizedPath = url.standardizedFileURL.path.lowercased()
        return "\(bundleIdentifier)|\(normalizedPath)"
    }
}
