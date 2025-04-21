import AppKit
import SwiftUI
import SwiftyBeaver

struct FavButtonNPopup: View {
    @State private var showFavTreePopup = false
    @State private var favTreeStruct: [CustomFile] = []
    @State private var selectedFile: CustomFile? = nil
    let lineLimit = 250

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: {
                    log.debug("Back: navigating to previous directory")
                }) {
                    Image(systemName: "arrowshape.backward")
                }
                .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)

                Button(action: {
                    log.debug("Forward: navigating to next directory")
                }) {
                    Image(systemName: "arrowshape.right")
                }
                .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)
                .disabled(true)

                Button(action: {
                    log.debug("Navigation between favorites")
                    showFavTreePopup.toggle()
                }) {
                    Image(systemName: "menucard")
                }
                .shadow(color: .blue.opacity(0.15), radius: 8, x: 0, y: 1)
                .help("Go up to directory Menu")
                .buttonStyle(.plain)
                .popover(isPresented: $showFavTreePopup, arrowEdge: .bottom) {
                    buildFavTreeMenu()
                        .frame(minWidth: 300, idealWidth: 480, maxWidth: 550,
                               minHeight: 380, idealHeight: 540, maxHeight: 800)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
                }
            }
        }
    }

        // MARK: -
    func buildFavTreeMenu() -> some View {
        log.debug("builFavTreeMenu()")
        return TreeView(files: $favTreeStruct, selectedFile: $selectedFile)
            .padding(6)
            .font(.custom("Helvetica Neue", size: 11).weight(.light))
            .foregroundColor(Color(#colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1)))
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3), value: favTreeStruct)
            .onAppear {
                Task(priority: .background) {
                    await fetchFavTree()
                }
            }
    }

        // MARK: -
    @MainActor
    private func fetchFavTree() async {
        log.debug("fetchFavTree()")
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
