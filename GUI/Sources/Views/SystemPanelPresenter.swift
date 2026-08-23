import AppKit

// MARK: - System Panel Presenter
@MainActor
enum SystemPanelPresenter {
    // MARK: - Present
    static func response(for panel: NSSavePanel, relativeTo parent: NSWindow? = nil) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            if let parent = parent ?? WindowContextResolver.presentationHost() {
                panel.beginSheetModal(for: parent) { response in
                    continuation.resume(returning: response)
                }
            } else {
                panel.begin { response in
                    continuation.resume(returning: response)
                }
            }
        }
    }

}
