import AppKit
import SwiftUI
import SwiftyBeaver

struct FavButtonNPopup: View {
    @State private var showFavTreePopup = false
    @State private var favTreeStruct: [CustomFile] = []
    @State private var selectedFile: CustomFile? = nil

    var body: some View {
        let msg1 = "Navigation between favorites"
        let msg2 = "Back: navigating to previous directory"
        let msg3 = "Forward: navigating to next directory"

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: {
                    log.debug(msg2)
                }) {
                    Image(systemName: "arrowshape.backward")
                }
                .shadow(color: .blue.opacity(0.15), radius: 5.0, x: 1, y: 1)
                .help(msg2)

                Button(action: {
                    log.debug(msg3)
                }) {
                    Image(systemName: "arrowshape.right")
                }
                .shadow(color: .blue.opacity(0.15), radius: 5.0, x: 1, y: 1)
                .disabled(true)
                .help(msg3)

                Button(action: {
                    log.debug(msg1)
                    showFavTreePopup.toggle()
                }) {
                    Image(systemName: "menucard")
                }
                .shadow(color: .blue.opacity(0.15), radius: 5.0, x: 1, y: 1)
                .buttonStyle(.plain)
                .popover(isPresented: $showFavTreePopup, arrowEdge: .bottom) {
                    buildFavTreeMenu()
                        .frame(
                            minWidth: 300,
                            idealWidth: 480,
                            maxWidth: 550,
                            minHeight: 380,
                            idealHeight: 540,
                            maxHeight: 800
                        )
                        .background(.ultraThinMaterial)
                        .cornerRadius(3)
                        .shadow(color: Color.black.opacity(0.3), radius: 5.0, x: 2, y: 4)
                }
                .help(msg1)
            }
        }
    }

    // MARK: -
    func buildFavTreeMenu() -> some View {
        log.debug(#function)
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
