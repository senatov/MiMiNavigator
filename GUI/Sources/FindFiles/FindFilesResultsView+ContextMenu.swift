import SwiftUI
import FindFilesKit

// MARK: - Results Context Menu
extension FindFilesResultsView {
    // MARK: - Context Menu

    @ViewBuilder
    func resultContextMenu(selection: Set<FindFilesResult.ID>) -> some View {
        let selected = viewModel.results.filter { selection.contains($0.id) }
        let actionable = selected.filter { !$0.isInsideArchive && !$0.isPasswordProtected }
        if selected.count == 1, let result = selected.first {
            Button("Go to File") {
                if let state = appState { viewModel.goToFile(result: result, appState: state) }
            }
            .disabled(appState == nil)
            Button("Reveal in Finder") { viewModel.revealInFinder(result: result) }
        }
        Button(selected.count == 1 ? "Open" : "Open \(selected.count) Items") {
            viewModel.openResults(actionable)
        }
        .disabled(actionable.isEmpty)
        Divider()
        Button(selected.count == 1 ? "Copy to Folder…" : "Copy \(selected.count) Items to Folder…") {
            viewModel.copyResults(actionable)
        }
        .disabled(actionable.isEmpty)
        Button(selected.count == 1 ? "Move to Folder…" : "Move \(selected.count) Items to Folder…") {
            viewModel.moveResults(actionable)
        }
        .disabled(actionable.isEmpty)
        Button(selected.count == 1 ? "Move to Trash" : "Move \(selected.count) Items to Trash", role: .destructive) {
            viewModel.trashResults(actionable)
        }
        .disabled(actionable.isEmpty)
        Divider()
        Button(selected.count == 1 ? "Copy Path" : "Copy \(selected.count) Paths") {
            viewModel.copyPaths(for: selected)
        }
        Divider()
        Button("Select All") { viewModel.selectAllResults() }
        Button("Copy All Paths") { viewModel.copyResultPaths() }
            .disabled(viewModel.results.isEmpty)
        Button("Export Results…") { viewModel.exportResults() }
            .disabled(viewModel.results.isEmpty)
    }

}
