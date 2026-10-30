import SwiftUI

// MARK: - Shared Search Location
struct FindFilesSearchLocation: View {
    @Bindable var viewModel: FindFilesViewModel
    var onSubmit: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 8) {
            Label("Search in", systemImage: "folder")
                .fixedSize()
            SearchHistoryComboBox(
                text: $viewModel.searchDirectory,
                historyKey: .searchDirectory,
                placeholder: "Directory path",
                completes: onSubmit == nil,
                onSubmit: {
                    if let onSubmit { onSubmit() }
                    else { viewModel.startSearch() }
                }
            )
            .frame(height: 24)
            Button(action: browseDirectory) {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(ThemedButtonStyle())
            .help("Choose a directory")
        }
    }
    // MARK: - Choose Directory
    private func browseDirectory() {
        Task { @MainActor in
            let path = (viewModel.searchDirectory as NSString).expandingTildeInPath
            guard let url = await FindFilesOperationPresenter.chooseLocation(
                prompt: "Select",
                message: "Choose a directory to search",
                initialURL: path.isEmpty ? nil : URL(fileURLWithPath: path),
                canChooseFiles: false
            ) else { return }
            FindFilesCoordinator.shared.sheetWindow?.makeFirstResponder(nil)
            viewModel.searchDirectory = url.path
        }
    }
}
