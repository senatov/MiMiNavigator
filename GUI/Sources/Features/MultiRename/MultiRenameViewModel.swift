// MultiRenameViewModel.swift
// MiMiNavigator

import Foundation

// MARK: - Multi Rename View Model
@MainActor
@Observable
final class MultiRenameViewModel {
    var scope = MultiRenameScope.directory
    var nameMask = "[N]"
    var extensionMask = "[E]"
    var searchText = ""
    var replacementText = ""
    var useRegex = false
    var caseSensitive = false
    var counterStart = 1
    var counterStep = 1
    var counterDigits = 1
    var caseMode = MultiRenameCaseMode.unchanged
    var errorMessage: String?
    var isRenaming = false
    var completionMessage: String?
    private var allSources: [MultiRenameSource] = []
    private var selectedSources: [MultiRenameSource] = []
    private var appState: AppState?
    private var panel = FavPanelSide.left
    private let engine = MultiRenameEngine()

    var canUseSelection: Bool { !selectedSources.isEmpty }
    var activeSources: [MultiRenameSource] { scope == .selection ? selectedSources : allSources }
    var previewItems: [MultiRenamePreviewItem] { MultiRenameEngine.preview(sources: activeSources, rule: rule) }
    var canRename: Bool { !isRenaming && previewItems.contains(where: \.isChanged) && previewItems.allSatisfy { $0.issue == nil } }

    func configure(allSources: [MultiRenameSource], selectedSources: [MultiRenameSource], panel: FavPanelSide, appState: AppState) {
        self.allSources = allSources
        self.selectedSources = selectedSources
        self.panel = panel
        self.appState = appState
        scope = selectedSources.isEmpty ? .directory : .selection
        errorMessage = nil
        completionMessage = nil
    }

    func reset() {
        nameMask = "[N]"
        extensionMask = "[E]"
        searchText = ""
        replacementText = ""
        useRegex = false
        caseSensitive = false
        counterStart = 1
        counterStep = 1
        counterDigits = 1
        caseMode = .unchanged
        completionMessage = nil
    }

    func rename() {
        let items = previewItems
        guard canRename else { return }
        isRenaming = true
        errorMessage = nil
        Task {
            do {
                let result = try await engine.rename(items)
                completionMessage = "Renamed \(result.renamedCount) item(s)"
                if let appState {
                    await appState.scanner.clearCooldown(for: panel)
                    await appState.refreshFiles(for: panel, force: true)
                    appState.setMarkedFiles([], for: panel)
                    reloadSources(from: appState, panel: panel)
                }
                log.info("[MultiRename] renamed \(result.renamedCount) items")
            } catch {
                errorMessage = error.localizedDescription
                log.error("[MultiRename] \(error.localizedDescription)")
            }
            isRenaming = false
        }
    }

    // MARK: - Reload Sources
    private func reloadSources(from appState: AppState, panel: FavPanelSide) {
        allSources = appState.displayedFiles(for: panel)
            .filter { !$0.isParentEntry }
            .map { MultiRenameSource(url: $0.urlValue, isDirectory: $0.isDirectory) }
        selectedSources = []
        scope = .directory
    }

    private var rule: MultiRenameRule {
        MultiRenameRule(nameMask: nameMask, extensionMask: extensionMask, searchText: searchText, replacementText: replacementText, useRegex: useRegex, caseSensitive: caseSensitive, counterStart: counterStart, counterStep: counterStep, counterDigits: counterDigits, caseMode: caseMode)
    }
}
