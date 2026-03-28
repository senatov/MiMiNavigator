// AppInfo.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Application info for "Open With" context menu — name, icon, bundle ID.

import AppKit
import Foundation
import UniformTypeIdentifiers


// MARK: - Application Info

/// Represents an application that can open a file.
struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let icon: NSImage
    let url: URL
    let isDefault: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
