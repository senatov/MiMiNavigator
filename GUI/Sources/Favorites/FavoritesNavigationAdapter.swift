    //
    // FavoritesNavigationAdapter.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 17.01.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    //
    // Adapter to connect FavoritesKit with MiMiNavigator's AppState

    import FavoritesKit
    import FileModelKit
    import Foundation

    // MARK: - Adapter connecting FavoritesKit to AppState
    @MainActor
    final class FavoritesNavigationAdapter: FavoritesNavigationDelegate {

        private let appState: AppState

        init(appState: AppState) {
            self.appState = appState
        }

        // MARK: - FavoritesNavigationDelegate

        var focusedPanel: FavPanelSide {
            appState.focusedPanel == .left ? .left : .right
        }

        func setFocusedPanel(_ panel: FavPanelSide) {
            appState.focusedPanel = panel == .left ? .left : .right
        }

        func navigate(to url: URL, panel: FavPanelSide) async {
            let targetPanel: PanelSide = panel == .left ? .left : .right

            log.info("\(#function) url=\(url.path) panel=\(panel)")

            // Update path
            appState.updatePath(url.path, for: targetPanel)

            // Update selectedDir for UI consistency
            let file = CustomFile(name: url.lastPathComponent, path: url.path)
            appState.selectedDir.selectedFSEntity = file

            // Refresh files
            await appState.scanner.resetRefreshTimer(for: targetPanel)
            await appState.scanner.refreshFiles(currSide: targetPanel)
        }

        func navigateBack(panel: FavPanelSide) {
            log.info("\(#function) panel=\(panel)")

            let targetPanel: PanelSide = panel == .left ? .left : .right
            let history = appState.navigationHistory(for: targetPanel)

            guard let path = history.goBack() else {
                log.debug("\(#function) no history to go back to")
                return
            }

            log.debug("\(#function) goBack returned path=\(path)")

            Task {
                appState.isNavigatingFromHistory = true
                log.debug("\(#function) set isNavigatingFromHistory=true")
                await navigate(to: path, panel: panel)
                appState.isNavigatingFromHistory = false
                log.debug("\(#function) set isNavigatingFromHistory=false")
            }
        }

        func navigateForward(panel: FavPanelSide) {
            log.info("\(#function) panel=\(panel)")

            let targetPanel: PanelSide = panel == .left ? .left : .right
            let history = appState.navigationHistory(for: targetPanel)

            guard let path = history.goForward() else {
                log.debug("\(#function) no history to go forward to")
                return
            }

            log.debug("\(#function) goForward returned path=\(path)")

            Task {
                appState.isNavigatingFromHistory = true
                log.debug("\(#function) set isNavigatingFromHistory=true")
                await navigate(to: path, panel: panel)
                appState.isNavigatingFromHistory = false
                log.debug("\(#function) set isNavigatingFromHistory=false")
            }
        }

        func navigateUp(panel: FavPanelSide) {
            log.info("\(#function) panel=\(panel)")

            let currentPath = panel == .left ? appState.leftPath : appState.rightPath
            let parentURL = URL(fileURLWithPath: currentPath).deletingLastPathComponent()

            guard parentURL.path != currentPath else {
                log.debug("\(#function) already at root")
                return
            }

            Task {
                await navigate(to: parentURL, panel: panel)
            }
        }

        func navigateToURL(_ url: URL, panel: FavoritesKit.FavPanelSide) async {
            // Forward to the main navigation implementation
            await navigate(to: url, panel: panel)
        }

        func currentURL(for panel: FavoritesKit.FavPanelSide) -> URL {
            // Convert AppState path to URL
            let path = panel == .left ? appState.leftPath : appState.rightPath
            return URL(fileURLWithPath: path)
        }

        func canGoBack(panel: FavPanelSide) -> Bool {
            let targetPanel: PanelSide = panel == .left ? .left : .right
            return appState.navigationHistory(for: targetPanel).canGoBack
        }

        func canGoForward(panel: FavPanelSide) -> Bool {
            let targetPanel: PanelSide = panel == .left ? .left : .right
            return appState.navigationHistory(for: targetPanel).canGoForward
        }

        func currentPath(for panel: FavPanelSide) -> String {
            panel == .left ? appState.leftPath : appState.rightPath
        }
    }

    // MARK: - Extension to convert between PanelSide and FavPanelSide
    extension PanelSide {
        var toFavPanelSide: FavPanelSide {
            self == .left ? .left : .right
        }

        init(from favPanel: FavPanelSide) {
            self = favPanel == .left ? .left : .right
        }
    }
