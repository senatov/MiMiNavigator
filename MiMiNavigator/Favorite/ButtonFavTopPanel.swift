import AppKit
import SwiftUI
import SwiftyBeaver

// MARK: -
struct ButtonFavTopPanel: View {

    @State private var favTreeStruct: [CustomFile] = []
    @EnvironmentObject var appState: AppState
    let panelSide: PanelSide

    // MARK: -
    init(selectedSide: PanelSide) {
        log.info("ButtonFavTopPanel init" + " for side \(selectedSide)")
        self.panelSide = selectedSide
    }

    // MARK: -
    public var body: some View {
        log.info(#function)
        return VStack(alignment: .leading, spacing: 4) { navigationControls }
    }

    // MARK: -
    private var navigationControls: some View {
        log.info(#function)
        return HStack(spacing: 6) {
            backButton()
            forwardButton()
            menuButton()
        }
    }

    // MARK: -
    private func menuButton() -> some View {
        log.info(#function + " - \(String(describing: panelSide))")
        return Button(action: {
            log.info("Navigation between favorites")
            if favTreeStruct.isEmpty { Task { await fetchFavTree() } }
            appState.showFavTreePopup.toggle()
        }) {
            if panelSide == .left {
                Image(systemName: "sidebar.left")
                    .renderingMode(.original)
                    .foregroundColor(Color(#colorLiteral(red: 0, green: 0.3285208941, blue: 0.5748849511, alpha: 1)))
                    .scaleEffect(CGSize(width: 0.9, height: 1.3), anchor: .leading)
                    .border(Color(#colorLiteral(red: 0, green: 0.3285208941, blue: 0.5748849511, alpha: 1)))
            } else {
                Image(systemName: "sidebar.right")
                    .renderingMode(.original)
                    .foregroundColor(Color(#colorLiteral(red: 0.09019608051, green: 0, blue: 0.3019607961, alpha: 1)))
                    .scaleEffect(CGSize(width: 0.9, height: 1.3), anchor: .leading)
                    .border(Color(#colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1)))
            }
        }
        .shadow(color: .secondary.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .buttonStyle(.plain)
        .popover(isPresented: $appState.showFavTreePopup, arrowEdge: .bottom) {
            favoritePopover()
        }
        .help("Navigation between favorites - \(String(describing: panelSide))")
    }

    // MARK: -
    private func backButton() -> some View {
        Button(action: { log.info("Back: navigating to previous directory") }) {
            Image(systemName: "arrowshape.backward").renderingMode(.original)
        }
        .shadow(color: .secondary.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .help("Back: navigating to previous directory")
        .accessibilityLabel("Back button")
    }

    // MARK: -
    private func forwardButton() -> some View {
        Button(action: { log.info("Forward: navigating to next directory") }) {
            Image(systemName: "arrowshape.right").renderingMode(.original)
        }
        .shadow(color: .secondary.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .disabled(true)
        .help("Forward: navigating to next directory")
        .accessibilityLabel("Forward button")
    }

    // MARK: -
    private func favoritePopover() -> some View {
        log.info(#function)
        return FavTreeMnu(files: $favTreeStruct, panelSide: panelSide)
            .padding(6)
            .font(.custom("Helvetica Neue", size: 11).weight(.light))
            .foregroundColor(Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)))
    }

    // MARK: -
    @MainActor
    private func fetchFavTree() async {
        //log.info(#function)
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
    private func fetchFavNetVolumes(from scanner: FavScanner) async
        -> [CustomFile]
    {
        //log.info(#function)
        await withCheckedContinuation { continuation in
            scanner.scanFavoritesAndNetworkVolumes { files in
                continuation.resume(returning: files)
            }
        }
    }
}
