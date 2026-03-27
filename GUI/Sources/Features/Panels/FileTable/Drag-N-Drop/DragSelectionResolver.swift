// DragSelectionResolver.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 16.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Resolves which files participate in a drag session.
//   Uses filesForOperation (marked first, then selected) to get real CustomFile objects.
//   For remote files returns their actual remote urlValue — never fileURLWithPath.

import AppKit
import FileModelKit

struct DragSelectionResolver {

    @MainActor
    static func resolve(from appState: AppState, side: FavPanelSide) -> [CustomFile] {
        appState.filesForOperation(on: side)
    }

    @MainActor
    static func resolveURLs(from appState: AppState, side: FavPanelSide) -> [URL] {
        resolve(from: appState, side: side).map { $0.urlValue }
    }
}
