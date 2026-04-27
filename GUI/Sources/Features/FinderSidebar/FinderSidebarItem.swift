// FinderSidebarItem.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.04.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Finder Sidebar Item
struct FinderSidebarItem: Identifiable {
    let title: String
    let systemImage: String
    let tint: Color
    let action: FinderSidebarAction
    let canUnmount: Bool

    var id: String { "\(title)-\(identityKey)" }

    // MARK: - Identity Key
    var identityKey: String {
        switch action {
        case .airDrop:
            return "airdrop"
        case .network:
            return "network"
        case .history:
            return "history"
        case .navigate(let url), .openIfExists(let url):
            return url.isFileURL ? Self.canonicalIdentity(for: url) : url.absoluteString
        }
    }

    // MARK: - File URL
    var fileURL: URL? {
        switch action {
        case .navigate(let url), .openIfExists(let url):
            return url.isFileURL ? url : nil
        default:
            return nil
        }
    }

    // MARK: - Help Text
    var helpText: String {
        fileURL?.path ?? title
    }

    // MARK: - Visibility
    var shouldShow: Bool {
        guard let fileURL else { return true }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Init
    init(title: String, systemImage: String, tint: Color = .primary, action: FinderSidebarAction, canUnmount: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
        self.canUnmount = canUnmount
    }

    // MARK: - Canonical Identity
    private static func canonicalIdentity(for url: URL) -> String {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        if path.contains("/Library/Mobile Documents/com~apple~CloudDocs") {
            return "icloud-drive"
        }
        return path
    }
}

// MARK: - Finder Sidebar Action
enum FinderSidebarAction {
    case airDrop
    case network
    case history
    case navigate(URL)
    case openIfExists(URL)
}
