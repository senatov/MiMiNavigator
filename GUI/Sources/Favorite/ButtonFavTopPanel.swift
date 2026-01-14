import AppKit
import SwiftUI

// MARK: -
struct ButtonFavTopPanel: View {
    @Environment(AppState.self) var appState
    @State private var favTreeStruct: [CustomFile] = []
    @State private var showBackPopover: Bool = false
    @State private var showForwardPopover: Bool = false
    @State private var showUpPopover: Bool = false
    @State private var showFavTreePopup: Bool = false  // Local state for each panel
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
            showFavTreePopup.toggle()  // Use local state
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
                .interactiveDismissDisabled()  // Don't close on click outside
        }
        .help("Navigation between favorites - << \(String(describing: panelSide))>>")
    }

    // MARK: -
    private func backButton() -> some View {
        log.debug(#function)
        return Button(action: {
            log.debug("Backward: navigating to previous directory")
            showBackPopover.toggle()
        }) {
            Image(systemName: "arrowshape.backward").renderingMode(.original)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .popover(isPresented: $showBackPopover, arrowEdge: .bottom) {
            backPopover()
        }
        .help("Back: navigating to previous directory")
        .accessibilityLabel("Back button")
    }

    // MARK: -
    private func upButton() -> some View {
        log.debug(#function)
        return Button(action: {
            log.debug("Up: navigating to up directory")
            showUpPopover.toggle()
        }) {
            Image(systemName: "arrowshape.up").renderingMode(.original)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .popover(isPresented: $showUpPopover, arrowEdge: .bottom) {
            forwardPopover()
        }
        .help("Up: navigating to up directory")
        .accessibilityLabel("up button")
    }

    // MARK: -
    private func forwardButton() -> some View {
        log.debug(#function)
        return Button(action: {
            log.debug("Forward: navigating to next directory")
            showForwardPopover.toggle()
        }) {
            Image(systemName: "arrowshape.right").renderingMode(.original)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .popover(isPresented: $showForwardPopover, arrowEdge: .bottom) {
            forwardPopover()
        }
        .help("Forward: navigating to next directory")
        .accessibilityLabel("Forward button")
    }

    // MARK: -
    private func forwardPopover() -> some View {
        log.debug(#function)
        return VStack(alignment: .leading) {
            ForEach(appState.selectionsHistory.recentSelections, id: \.self) { path in
                Button(action: {
                    Task {
                        if panelSide == .left {
                            await appState.scanner.setLeftDirectory(pathStr: path)
                            await appState.refreshLeftFiles()
                        } else {
                            await appState.scanner.setRightDirectory(pathStr: path)
                            await appState.refreshRightFiles()
                        }
                        showForwardPopover = false
                    }
                }) {
                    Text(path)
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                        .padding(.vertical, 2)
                }
                Divider()
            }
        }
        .padding(6)
        .frame(maxWidth: 400, maxHeight: 300)
    }

    // MARK: -
    private func backPopover() -> some View {
        log.debug(#function)
        return HistoryPopoverView(isPresented: $showBackPopover, panelSide: panelSide)
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
