import AppKit
import SwiftUI

// MARK: -
struct ButtonFavTopPanel: View {
    @Environment(AppState.self) var appState
    @State private var favTreeStruct: [CustomFile] = []
    @State private var showBackPopover: Bool = false
    @State private var showForwardPopover: Bool = false
    @State private var showFavTreePopup: Bool = false
    let panelSide: PanelSide

    // MARK: -
    init(selectedSide: PanelSide) {
        log.debug("ButtonFavTopPanel init" + " for side <<\(selectedSide)>>")
        self.panelSide = selectedSide
    }

    // MARK: -
    var body: some View {
        log.debug(#function)
        return VStack(alignment: .leading, spacing: 4) { navigationControls }
    }

    // MARK: -
    private var navigationControls: some View {
        log.debug(#function)
        return HStack(spacing: 6) {
            backButton()
            upButton()
            forwardButton()
            menuButton()
        }
    }

    // MARK: -
    private func menuButton() -> some View {
        log.debug(#function + " - <<\(String(describing: panelSide))>>")
        return Button(action: {
            log.debug("Navigation between favorites")
            if favTreeStruct.isEmpty {
                Task { await fetchFavTree() }
            }
            appState.focusedPanel = panelSide
            showFavTreePopup.toggle()
        }) {
            if panelSide == .left {
                Image(systemName: "sidebar.left")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .foregroundColor(FilePanelStyle.dirNameColor)
                    .scaleEffect(CGSize(width: 0.9, height: 1.3), anchor: .leading)
                    .border(FilePanelStyle.fileNameColor)
            } else {
                Image(systemName: "sidebar.right")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .foregroundStyle(FilePanelStyle.fileNameColor)
                    .scaleEffect(CGSize(width: 0.9, height: 1.3), anchor: .leading)
                    .border(FilePanelStyle.fileNameColor)
            }
        }
        .shadow(color: .secondary.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .buttonStyle(.plain)
        .popover(isPresented: $showFavTreePopup, arrowEdge: .bottom) {
            favoritePopover(targetSide: appState.focusedPanel)
                .interactiveDismissDisabled()
        }
        .help("Navigation between favorites - << \(String(describing: panelSide))>>")
    }

    // MARK: - Back button: left click = navigate back, right click = show history
    private func backButton() -> some View {
        log.debug(#function)
        return Image(systemName: "arrowshape.backward")
            .renderingMode(.original)
            .contentShape(Rectangle())
            .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
            .opacity(appState.selectionsHistory.canGoBack ? 1.0 : 0.4)
            .onTapGesture {
                log.debug("Back button click: navigating back")
                navigateBack()
            }
            .contextMenu {
                backContextMenu()
            }
            .help("Click: go back | Right-click: show history")
            .accessibilityLabel("Back button")
    }

    // MARK: - Up button: click = go to parent directory
    private func upButton() -> some View {
        log.debug(#function)
        return Button(action: {
            log.debug("Up: navigating to parent directory")
            navigateUp()
        }) {
            Image(systemName: "arrowshape.up").renderingMode(.original)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .help("Go to parent directory")
        .accessibilityLabel("Up button")
    }

    // MARK: - Forward button: left click = navigate forward, right click = show history
    private func forwardButton() -> some View {
        log.debug(#function)
        return Image(systemName: "arrowshape.right")
            .renderingMode(.original)
            .contentShape(Rectangle())
            .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
            .opacity(appState.selectionsHistory.canGoForward ? 1.0 : 0.4)
            .onTapGesture {
                log.debug("Forward button click: navigating forward")
                navigateForward()
            }
            .contextMenu {
                forwardContextMenu()
            }
            .help("Click: go forward | Right-click: show history")
            .accessibilityLabel("Forward button")
    }

    // MARK: - Navigation actions
    private func navigateBack() {
        log.info("navigateBack() on \(panelSide)")
        guard let path = appState.selectionsHistory.goBack() else {
            log.debug("navigateBack: no history to go back to")
            return
        }
        Task {
            await navigateToPath(path)
        }
    }

    private func navigateForward() {
        log.info("navigateForward() on \(panelSide)")
        guard let path = appState.selectionsHistory.goForward() else {
            log.debug("navigateForward: no history to go forward to")
            return
        }
        Task {
            await navigateToPath(path)
        }
    }

    private func navigateUp() {
        log.info("navigateUp() on \(panelSide)")
        let currentPath = panelSide == .left ? appState.leftPath : appState.rightPath
        let parentURL = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
        let parentPath = parentURL.path
        guard parentPath != currentPath else {
            log.debug("navigateUp: already at root")
            return
        }
        Task {
            await navigateToPath(parentPath)
        }
    }

    @MainActor
    private func navigateToPath(_ path: String) async {
        log.info("navigateToPath(\(path)) on \(panelSide)")
        if panelSide == .left {
            await appState.scanner.setLeftDirectory(pathStr: path)
            await appState.refreshLeftFiles()
        } else {
            await appState.scanner.setRightDirectory(pathStr: path)
            await appState.refreshRightFiles()
        }
    }

    // MARK: - Context menus (right-click)
    @ViewBuilder
    private func backContextMenu() -> some View {
        let backHistory = appState.selectionsHistory.getBackHistory(limit: 15)
        if backHistory.isEmpty {
            Text("No back history")
                .foregroundStyle(.secondary)
        } else {
            ForEach(backHistory, id: \.self) { path in
                Button(action: {
                    Task {
                        appState.selectionsHistory.setCurrent(to: path)
                        await navigateToPath(path)
                    }
                }) {
                    Text(shortenPath(path))
                }
            }
        }
    }

    @ViewBuilder
    private func forwardContextMenu() -> some View {
        let forwardHistory = appState.selectionsHistory.getForwardHistory(limit: 15)
        if forwardHistory.isEmpty {
            Text("No forward history")
                .foregroundStyle(.secondary)
        } else {
            ForEach(forwardHistory, id: \.self) { path in
                Button(action: {
                    Task {
                        appState.selectionsHistory.setCurrent(to: path)
                        await navigateToPath(path)
                    }
                }) {
                    Text(shortenPath(path))
                }
            }
        }
    }

    // MARK: - Helper: shorten long paths for menu display
    private func shortenPath(_ path: String) -> String {
        let maxLen = 50
        guard path.count > maxLen else { return path }
        let url = URL(fileURLWithPath: path)
        let components = url.pathComponents
        if components.count <= 3 {
            return path
        }
        // Show: /first/.../last two components
        let first = components[0] == "/" ? "/" : components[0]
        let last = components.suffix(2).joined(separator: "/")
        return "\(first)…/\(last)"
    }

    // MARK: -
    private func favoritePopover(targetSide: PanelSide) -> some View {
        log.debug(#function)
        return FavTreePopup(files: $favTreeStruct, isPresented: $showFavTreePopup, panelSide: targetSide)
            .padding(6)
            .font(.custom("Helvetica Neue", size: 11).weight(.light))
            .foregroundStyle(FilePanelStyle.fileNameColor)
    }

    // MARK: -
    @MainActor
    private func fetchFavTree() async {
        log.debug(#function)
        let favScanner = FavScanner()
        favTreeStruct = favScanner.scanOnlyFavorites()
        let files = await fetchFavNetVolumes(from: favScanner)
        withAnimation(
            .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3)
        ) {
            favTreeStruct.append(contentsOf: files)
        }
    }

    // MARK: -
    private func fetchFavNetVolumes(from scanner: FavScanner) async -> [CustomFile] {
        log.debug(#function)
        return await withCheckedContinuation { (continuation: CheckedContinuation<[CustomFile], Never>) in
            scanner.scanFavoritesAndNetworkVolumes { files in
                continuation.resume(returning: files)
            }
        }
    }
}
