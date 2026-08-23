// FindFilesViewModel+Actions.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Presentation entry points for actions on Find Files results.

import FindFilesKit
import Foundation

// MARK: - Actions on Results
extension FindFilesViewModel {
    func goToFile(result: FindFilesResult, appState: AppState) {
        Task { @MainActor in
            await FindFilesResultCoordinator().navigate(to: result, appState: appState)
        }
    }

    func openFile(result: FindFilesResult) {
        FindFilesSystemActions.open(result)
    }

    func revealInFinder(result: FindFilesResult) {
        FindFilesSystemActions.reveal(result)
    }

    func copyResultPaths() {
        FindFilesSystemActions.copyPaths(results)
    }

    func exportResults() {
        let capturedResults = results
        let summary = lastSearchSummary
        Task { @MainActor [weak self] in
            guard let url = await FindFilesOperationPresenter.chooseExportDestination() else { return }
            do {
                try await FindFilesExportWriter.shared.write(results: capturedResults, summary: summary, to: url)
                InAppNoticeCenter.shared.showToast(
                    "Exported \(capturedResults.count) result\(capturedResults.count == 1 ? "" : "s")",
                    scope: .findFiles,
                    systemImage: "square.and.arrow.up.fill",
                    tint: .blue
                )
            } catch {
                self?.errorMessage = "Export failed: \(error.localizedDescription)"
                log.error("[FindFiles] export failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Show in Panel
    func showInPanel(appState: AppState) {
        guard !results.isEmpty else { return }
        let panel = appState.focusedPanel
        let capturedResults = results
        Task { @MainActor in
            let content = await FindFilesResultCoordinator().buildPanelContent(from: capturedResults)
            appState.searchResultArchives[panel] = content.openedArchives
            appState.showSearchResults(content.files, virtualPath: "\u{1F50D} Search Results", on: panel)
            log.info("[FindFiles] showInPanel: \(content.files.count) files (\(content.openedArchives.count) archives)")
        }
    }
}
