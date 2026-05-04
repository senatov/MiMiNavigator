// AppState+PathBridge.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Per-panel path string bridge helpers.

import FileModelKit
import Foundation

// MARK: - Path Bridge
extension AppState {

    var leftPath: String {
        get { Self.pathString(for: leftURL) }
        set { leftURL = Self.url(fromPathString: newValue) }
    }

    var rightPath: String {
        get { Self.pathString(for: rightURL) }
        set { rightURL = Self.url(fromPathString: newValue) }
    }

    var savedLocalLeftPath: String? {
        get { savedLocalLeftURL?.path }
        set { savedLocalLeftURL = newValue.map { URL(fileURLWithPath: $0) } }
    }

    var savedLocalRightPath: String? {
        get { savedLocalRightURL?.path }
        set { savedLocalRightURL = newValue.map { URL(fileURLWithPath: $0) } }
    }

    func url(for panel: FavPanelSide) -> URL {
        switch panel {
            case .left: return leftURL
            case .right: return rightURL
        }
    }

    func path(for panel: FavPanelSide) -> String {
        switch panel {
            case .left: return leftPath
            case .right: return rightPath
        }
    }

    func breadcrumbDisplayPath(for panel: FavPanelSide) -> String {
        self[panel: panel].breadcrumbDisplayPath ?? path(for: panel)
    }

    func setPath(_ path: String, for panel: FavPanelSide) {
        log.debug("[AppState] setPath panel=\(panel) path=\(path)")
        if panel == .left {
            leftURL = Self.url(fromPathString: path)
        } else {
            rightURL = Self.url(fromPathString: path)
        }
    }

    nonisolated static func pathString(for url: URL) -> String {
        isRemotePath(url) ? url.absoluteString : url.path
    }

    nonisolated static func url(fromPathString path: String) -> URL {
        if let url = URL(string: path), isRemotePath(url) {
            return url
        }
        return URL(fileURLWithPath: path)
    }
}
