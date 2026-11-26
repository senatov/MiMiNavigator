import FileModelKit
import Foundation

// MARK: - Remote Batch Delete
extension BatchOpsCoord {
    // MARK: - Delete Files
    func performRemoteDelete(files: [CustomFile], source: URL, sourcePanel: FavPanelSide, appState: AppState) async {
        guard let connection = RemoteConnectionManager.shared.connection(for: source) else {
            FileOperationOutcomePresenter.failure(.delete, message: "No active connection to the remote server.")
            return
        }
        let panel = ProgressPanel.shared
        panel.show(icon: "trash", title: "Deleting remote items", status: "\(files.count) item(s) from remote server")
        var deleted: [CustomFile] = []
        for file in files {
            guard !panel.isCancelled else { break }
            do {
                try await connection.provider.deleteItem(at: file.pathStr, recursive: file.isDirectory)
                deleted.append(file)
                panel.appendLog("Deleted: \(file.nameStr)")
            } catch {
                panel.appendLog("Failed: \(file.nameStr) — \(error.localizedDescription)")
            }
        }
        let message = "Deleted \(deleted.count) of \(files.count) remote item(s)"
        let success = deleted.count == files.count
        panel.finish(success: success, message: message, autoClose: success)
        if panel.isCancelled {
            FileOperationOutcomePresenter.cancelled(.delete, message: message)
        } else if success {
            FileOperationOutcomePresenter.success(.delete, itemCount: deleted.count, sourceURLs: deleted.map(\.urlValue))
        } else {
            FileOperationOutcomePresenter.failure(.delete, message: message)
        }
        await appState.refreshAndSelectAfterRemoval(removedFiles: deleted, on: sourcePanel)
    }
}
