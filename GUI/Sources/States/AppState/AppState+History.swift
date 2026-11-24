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

    @discardableResult
    func navigateToHistory(_ url: URL, on panel: FavPanelSide, recordVisit: Bool = true) async -> Bool {
        if Self.isRemotePath(url) {
            guard RemoteConnectionManager.shared.connection(for: url) != nil else { return false }
        } else {
            guard Self.isExistingDirectory(url.path) else { return false }
        }
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
        let arrived = Self.isRemotePath(url)
            ? Self.remoteOrigin(from: self.url(for: panel).absoluteString) == Self.remoteOrigin(from: url.absoluteString)
                && self.url(for: panel).path == url.path
            : PathUtils.areEqual(path(for: panel), url.path)
        guard arrived else { return false }
        if recordVisit { navigationHistory(for: panel).navigateTo(url) }
        guard let snapshot, let selectedPath = snapshot.selectedPath,
              path(for: panel) == Self.pathString(for: url) else { return true }
        selectFileByURL(Self.url(fromPathString: selectedPath), on: panel)
        return true
    }

    func navigateBackInPanelHistory(on panel: FavPanelSide) async {
        guard historyNavigationInProgress.insert(panel).inserted else { return }
        defer { historyNavigationInProgress.remove(panel) }
        captureHistoryState(for: panel)
        guard let target = navigationHistory(for: panel).goBack() else { return }
        if !(await navigateToHistory(target, on: panel, recordVisit: false)) {
            _ = navigationHistory(for: panel).goForward()
            log.warning("[History] back navigation failed; restored history position panel=\(panel)")
        }
    }

    func navigateForwardInPanelHistory(on panel: FavPanelSide) async {
        guard historyNavigationInProgress.insert(panel).inserted else { return }
        defer { historyNavigationInProgress.remove(panel) }
        captureHistoryState(for: panel)
        guard let target = navigationHistory(for: panel).goForward() else { return }
        if !(await navigateToHistory(target, on: panel, recordVisit: false)) {
            _ = navigationHistory(for: panel).goBack()
            log.warning("[History] forward navigation failed; restored history position panel=\(panel)")
        }
    }
}
