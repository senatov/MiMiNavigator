//
//  PathNavigationService.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation

@MainActor
final class PathNavigationService {

    private let appState: AppState

    // MARK: - Singleton
    private static var _shared: PathNavigationService?

    static func shared(appState: AppState) -> PathNavigationService {
        if let existing = _shared {
            return existing
        }
        let instance = PathNavigationService(appState: appState)
        _shared = instance
        return instance
    }

    private init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API

    /// Navigate to a new path (used by breadcrumb, manual input, etc.)
    func navigate(
        to path: String,
        side: PanelSide
    ) async {

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        guard validate(path: trimmed) else {
            log.warning("[PathNav] invalid path: \(trimmed)")
            return
        }

        let url = URL(fileURLWithPath: trimmed)

        log.info("[PathNav] navigating \(side) → \(trimmed)")

        // 1. Update AppState (history + UI)
        appState.updatePath(url, for: side)

        // 2. Apply to scanner
        await setDirectory(path: trimmed, side: side)

        // 3. Force refresh (важно!)
        await refresh(side: side)
    }

    // MARK: - Validation

    private func validate(path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Scanner integration

    private func setDirectory(path: String, side: PanelSide) async {
        switch side {
            case .left:
                await appState.scanner.setLeftDirectory(pathStr: path)
            case .right:
                await appState.scanner.setRightDirectory(pathStr: path)
        }
    }

    private func refresh(side: PanelSide) async {
        // force refresh because user explicitly navigated
        await appState.scanner.forceRefreshAfterFileOp(side: side)

        switch side {
            case .left:
                await appState.refreshLeftFiles()
            case .right:
                await appState.refreshRightFiles()
        }
    }
}
