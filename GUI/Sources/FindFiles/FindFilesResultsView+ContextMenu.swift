import SwiftUI
import FindFilesKit

// MARK: - Results Context Menu
extension FindFilesResultsView {
    // MARK: - Context Menu

    @ViewBuilder
    func resultContextMenu(selection: Set<FindFilesResult.ID>) -> some View {
        let selected = viewModel.results.filter { selection.contains($0.id) }
        let actionable = selected.filter { $0.fileURL.isFileURL && !$0.isInsideArchive && !$0.isPasswordProtected }
        if selected.count == 1, let result = selected.first {
            Button {
                if let state = appState { viewModel.goToFile(result: result, appState: state) }
            } label: {
                ContextMenuLabel("Go to File", systemImage: "scope")
            }
            .disabled(appState == nil)
            Button { viewModel.revealInFinder(result: result) } label: { ContextMenuLabel("Reveal in Finder", systemImage: "folder") }
                .disabled(!result.fileURL.isFileURL)
        }
        Button {
            viewModel.openResults(actionable)
        } label: {
            ContextMenuLabel(selected.count == 1 ? "Open" : "Open \(selected.count) Items", systemImage: "arrow.up.right.square")
        }
        .disabled(actionable.isEmpty)
        Divider()
        Button {
            viewModel.copyResults(actionable)
        } label: {
            ContextMenuLabel(selected.count == 1 ? "Copy to Folder…" : "Copy \(selected.count) Items to Folder…", systemImage: "doc.on.doc")
        }
        .disabled(actionable.isEmpty)
        Button {
            viewModel.moveResults(actionable)
        } label: {
            ContextMenuLabel(selected.count == 1 ? "Move to Folder…" : "Move \(selected.count) Items to Folder…", systemImage: "arrow.right.doc.on.clipboard")
        }
        .disabled(actionable.isEmpty)
        Button(role: .destructive) {
            viewModel.trashResults(actionable)
        } label: {
            ContextMenuLabel(selected.count == 1 ? "Move to Trash" : "Move \(selected.count) Items to Trash", systemImage: "trash")
        }
        .disabled(actionable.isEmpty)
        Divider()
        Button {
            viewModel.copyPaths(for: selected)
        } label: {
            ContextMenuLabel(selected.count == 1 ? "Copy Path" : "Copy \(selected.count) Paths", systemImage: "link")
        }
        Divider()
        Button { viewModel.selectAllResults() } label: { ContextMenuLabel("Select All", systemImage: "checkmark.square") }
        Button { viewModel.copyResultPaths() } label: { ContextMenuLabel("Copy All Paths", systemImage: "doc.on.clipboard") }
            .disabled(viewModel.results.isEmpty)
        Button { viewModel.exportResults() } label: { ContextMenuLabel("Export Results…", systemImage: "square.and.arrow.up") }
            .disabled(viewModel.results.isEmpty)
    }

}
