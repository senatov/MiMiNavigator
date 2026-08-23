import AppKit

// MARK: - System Panel Presenter
@MainActor
enum SystemPanelPresenter {
    // MARK: - Present
    static func response(for panel: NSSavePanel, relativeTo parent: NSWindow? = nil) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            if let parent = parent ?? presentationWindow {
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

    private static var presentationWindow: NSWindow? {
        if let keyWindow = NSApp.keyWindow, keyWindow.isVisible { return keyWindow }
        if let mainWindow = NSApp.mainWindow, mainWindow.isVisible { return mainWindow }
        return NSApp.orderedWindows.first { WindowPresentationPolicy.isStandalone($0) && $0.isVisible }
    }
}
