import AppKit
import SwiftUI
import SwiftyBeaver

// MARK: -
struct ButtonTopPanelRight: View {

    @State private var favTreeStruct: [CustomFile] = []
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide = .right

    // MARK: -
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) { navigationControls }
    }

    // MARK: -
    private var navigationControls: some View {
        HStack(spacing: 6) {
            backButton
            forwardButton
            menuButton
        }
    }

    // MARK: -
    private var backButton: some View {
        Button(action: { log.info("Back: navigating to previous directory") }) {
            Image(systemName: "arrowshape.backward").renderingMode(.original)
        }
        .shadow(color: .blue.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .help("Back: navigating to previous directory")
        .accessibilityLabel("Back button")
    }

    // MARK: -
    private var forwardButton: some View {
        Button(action: { log.info("Forward: navigating to next directory") }) {
            Image(systemName: "arrowshape.right").renderingMode(.original)
        }
        .shadow(color: .blue.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .disabled(true)
        .help("Forward: navigating to next directory")
        .accessibilityLabel("Forward button")
    }

    // MARK: -
    private var menuButton: some View {
        log.info(#function)
        return Button(action: {
            log.info("Navigation between favorites")
            if favTreeStruct.isEmpty { Task { await fetchFavTree() } }
            appState.showFavTreePopup.toggle()
        }) {
            Image(systemName: "arrow.down.right").renderingMode(.original)
        }
        .shadow(color: .blue.opacity(0.15), radius: 5.0, x: 1, y: 1)
        .buttonStyle(.plain)
        .popover(isPresented: $appState.showFavTreePopup, arrowEdge: .bottom) {
            favoritePopover()
        }
        .help("Navigation between favorites - \(panelSide)")
    }

    // MARK: -
    private func favoritePopover() -> some View {
        log.info(#function)
        return FavTreeMnu(files: $favTreeStruct)
            .padding(6)
            .font(.custom("Helvetica Neue", size: 11).weight(.light))
            .foregroundColor(Color(#colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1)))
    }

    // MARK: -
    @MainActor
    private func fetchFavTree() async {
        //log.info(#function)
        let favScanner = FavScanner()
        favTreeStruct = favScanner.scanOnlyFavorites()
        let files = await fetchFavNetVolumes(from: favScanner)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3)) {
            favTreeStruct.append(contentsOf: files)
        }
    }

    // MARK: -
    private func fetchFavNetVolumes(from scanner: FavScanner) async -> [CustomFile] {
        //log.info(#function)
        await withCheckedContinuation { continuation in
            scanner.scanFavoritesAndNetworkVolumes { files in continuation.resume(returning: files) }
        }
    }
}
