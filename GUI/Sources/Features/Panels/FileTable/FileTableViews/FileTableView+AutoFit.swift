//
//  FileTableView+AutoFit.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 06.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

extension FileTableView {
    // MARK: - AutoFit Handling

    /// True when every directory in current panel has a resolved size.
    /// Reads live from appState.
    var allSizesResolved: Bool {
        let liveFiles = appState.displayedFiles(for: panelSide)
        return liveFiles.allSatisfy { file in
            guard file.isDirectory else { return true }
            if file.sizeIsExact { return true }
            if file.securityState != .normal { return true }
            if file.cachedDirectorySize != nil { return true }
            return false
        }
    }

    /// Schedule a deferred autofit that waits until all dir sizes are resolved.
    func scheduleAutoFitIfNeeded() {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }

        let currentPath = appState.path(for: panelSide)
        guard currentPath != lastAutoFitPath else {
            log.debug("[AutoFit] schedule skip — same path panel=\\(panelSide)")
            return
        }

        if let existing = pendingAutoFitTask, !existing.isCancelled {
            log.debug("[AutoFit] cancelling previous deferred task panel=\\(panelSide)")
            existing.cancel()
        }

        lastAutoFitPath = currentPath
        log.info("[AutoFit] schedule deferred autofit panel=\\(panelSide) path=\\(currentPath)")

        pendingAutoFitTask = Task { @MainActor in
            var pollCount = 0

            for _ in 0..<60 {
                if Task.isCancelled { return }
                if allSizesResolved { break }
                pollCount += 1
                try? await Task.sleep(for: .milliseconds(500))
            }

            if Task.isCancelled { return }

            let liveFiles = appState.displayedFiles(for: panelSide)
            log.info("[AutoFit] deferred pass 1 panel=\\(panelSide) polls=\\(pollCount) resolved=\\(allSizesResolved) files=\\(liveFiles.count)")

            lastAutoFitWidth = layout.containerWidth
            ColumnAutoFitter.autoFitAll(layout: layout, files: liveFiles)

            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }

            log.debug("[AutoFit] deferred pass 2 panel=\\(panelSide)")
            ColumnAutoFitter.autoFitAll(layout: layout, files: appState.displayedFiles(for: panelSide))

            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }

            log.debug("[AutoFit] deferred pass 3 (final) panel=\\(panelSide)")
            ColumnAutoFitter.autoFitAll(layout: layout, files: appState.displayedFiles(for: panelSide))
        }
    }

    /// Re-fit columns when panel width changes.
    private static var lastContainerWidthFitTime: Date = .distantPast

    func handleContainerWidthChange(_ newWidth: CGFloat) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }

        let liveFiles = appState.displayedFiles(for: panelSide)
        guard !liveFiles.isEmpty else { return }

        let delta = abs(newWidth - lastAutoFitWidth)
        guard delta > 12 else { return }

        let now = Date()
        guard now.timeIntervalSince(Self.lastContainerWidthFitTime) > 2.0 else { return }
        Self.lastContainerWidthFitTime = now

        log.debug("[AutoFit] resize refit panel=\\(panelSide) delta=\\(Int(delta))pt")
        lastAutoFitWidth = newWidth
        ColumnAutoFitter.autoFitAll(layout: layout, files: liveFiles)
    }
}
