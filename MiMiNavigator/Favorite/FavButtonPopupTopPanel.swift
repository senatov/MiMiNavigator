import AppKit
import SwiftUI
import SwiftyBeaver

// MARK: -
struct FavButtonPopupTopPanel: View {
    @StateObject var selection = SelectedDir()
    @State private var showFavTreePopup = false
    @State private var favTreeStruct: [CustomFile] = []


    // MARK: -
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            navigationControls
        }
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
        Button(action: {
            log.debug("Back: navigating to previous directory")
        }) {
            Image(systemName: "arrowshape.backward").renderingMode(.original)
        }
        .shadow(color: .blue.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .help("Back: navigating to previous directory")
    }

    // MARK: -
    private var forwardButton: some View {
        Button(action: {
            log.debug("Forward: navigating to next directory")
        }) {
            Image(systemName: "arrowshape.right").renderingMode(.original)
        }
        .shadow(color: .blue.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .disabled(true)
        .help("Forward: navigating to next directory")
    }

    // MARK: -
    private var menuButton: some View {
        Button(action: {
            log.debug("Navigation between favorites")
            if favTreeStruct.isEmpty {
                Task { await fetchFavTree() }
            }
            showFavTreePopup.toggle()
        }) {
            Image(systemName: "menucard").renderingMode(.original)
        }
        .shadow(color: .blue.opacity(0.15), radius: 5.0, x: 1, y: 1)
        .buttonStyle(.plain)
        .popover(isPresented: $showFavTreePopup, arrowEdge: .bottom) {
            favoritePopover()
        }
        .help("Navigation between favorites")
    }

    // MARK: -
    private func favoritePopover() -> some View {
        FavTreeMnu(files: $favTreeStruct, selected: selection)
            .padding(6)
            .font(.custom("Helvetica Neue", size: 11).weight(.light))
            .foregroundColor(
                Color(#colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1))
            )
            .animation(
                .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3),
                value: favTreeStruct
            )
    }

    // MARK: -
    @MainActor
    private func fetchFavTree() async {
        log.debug(#function)
        let favScanner = FavScanner()
        favTreeStruct = favScanner.scanOnlyFavorites()
        let files = await fetchFavoritesAsync(from: favScanner)
        favTreeStruct.append(contentsOf: files)
    }

    // MARK: -
    private func fetchFavoritesAsync(from scanner: FavScanner) async -> [CustomFile] {
        await withCheckedContinuation { continuation in
            scanner.scanFavoritesAndNetworkVolumes { files in
                continuation.resume(returning: files)
            }
        }
    }
}
