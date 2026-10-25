import FileModelKit
import Foundation

// MARK: - Panel History State
extension AppState {
    func captureHistoryState(for panel: FavPanelSide) {
        let currentURL = Self.url(fromPathString: path(for: panel))
        let selected = self[panel: panel].selectedFile
        let snapshot = PanelHistorySnapshot(
            sortKey: sortKey.rawValue,
            sortAscending: bSortAscending,
            selectedPath: selected.flatMap { $0.isParentEntry ? nil : Self.pathString(for: $0.urlValue) },
            viewMode: tabManager(for: panel).activeViewMode
        )
        navigationHistory(for: panel).setSnapshot(snapshot, for: currentURL)
        selectionsHistory.setSnapshot(snapshot, for: currentURL)
    }

    func navigateToHistory(_ url: URL, on panel: FavPanelSide) async {
        captureHistoryState(for: panel)
        let snapshot = navigationHistory(for: panel).snapshot(for: url)
            ?? selectionsHistory.snapshot(for: url)
        if let snapshot {
            if let key = SortKeysEnum(rawValue: snapshot.sortKey) {
                updateSorting(key: key, ascending: snapshot.sortAscending)
            }
            tabManager(for: panel).setActiveViewMode(snapshot.viewMode)
            let targetPath = Self.pathString(for: url)
            if let selectedPath = snapshot.selectedPath {
                directorySelectionRestore[panel, default: [:]][targetPath] = Self.url(fromPathString: selectedPath)
            } else {
                directorySelectionRestore[panel]?.removeValue(forKey: targetPath)
            }
        }
        isNavigatingFromHistory = true
        defer { isNavigatingFromHistory = false }
        await navigateToDirectory(Self.pathString(for: url), on: panel)
        guard let snapshot, let selectedPath = snapshot.selectedPath,
              path(for: panel) == Self.pathString(for: url) else { return }
        selectFileByURL(Self.url(fromPathString: selectedPath), on: panel)
    }

    func navigateBackInPanelHistory(on panel: FavPanelSide) async {
        captureHistoryState(for: panel)
        guard let target = navigationHistory(for: panel).goBack() else { return }
        await navigateToHistory(target, on: panel)
    }

    func navigateForwardInPanelHistory(on panel: FavPanelSide) async {
        captureHistoryState(for: panel)
        guard let target = navigationHistory(for: panel).goForward() else { return }
        await navigateToHistory(target, on: panel)
    }
}
