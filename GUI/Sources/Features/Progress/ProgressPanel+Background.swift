import AppKit

// MARK: - Background File Operations
extension ProgressPanel {
    // MARK: - Run
    static func runFileOperation(
        inBackground: Bool,
        operation: FileOperationOutcomePresenter.Operation,
        action: () async -> Void
    ) async {
        guard inBackground else {
            await action()
            return
        }
        let progress = ProgressPanel(isBackground: true)
        backgroundWindows[ObjectIdentifier(progress)] = progress
        await $background.withValue(progress) {
            progress.show(icon: operation.icon, title: operation.actionTitle, status: "Starting…")
            progress.actionButton?.isEnabled = false
            await action()
            if !progress.isFinished {
                progress.finish(success: false, message: "Operation ended without a result.", autoClose: false)
            }
        }
    }

    // MARK: - Record Result
    static func recordBackgroundResult(success: Bool, title: String, details: String?) {
        guard let background else { return }
        background.appendLog(title)
        if let details, !details.isEmpty { background.appendLog(details) }
        if !background.isFinished {
            background.finish(success: success, message: title, autoClose: success)
        }
    }
}
