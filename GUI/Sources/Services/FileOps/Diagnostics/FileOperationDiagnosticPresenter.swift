import AppKit
import SwiftUI

@MainActor
final class FileOperationDiagnosticPresenter: NSObject, NSWindowDelegate {
    static let shared = FileOperationDiagnosticPresenter()

    private var panel: NSPanel?

    private override init() {}

    // MARK: - Show
    func show(_ info: FileOperationDiagnosticInfo) {
        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(
            rootView: FileOperationDiagnosticDialog(info: info) { [weak self] in
                self?.close()
            }
        )
        position(panel)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    // MARK: - Make Panel
    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 280), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = false
        panel.toolbarStyle = .unified
        WindowPresentationPolicy.apply(.standalone, to: panel)
        PanelTitleHelper.applyIconTitle(to: panel, systemImage: "exclamationmark.triangle", title: "File Operation Error")
        panel.delegate = self
        return panel
    }

    // MARK: - Position
    private func position(_ panel: NSPanel) {
        if let main = NSApp.mainWindow {
            let frame = main.frame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.midY - panel.frame.height / 2
            ))
        } else {
            panel.center()
        }
    }

    // MARK: - Close
    private func close() {
        guard let panel else { return }
        panel.orderOut(nil)
        panel.contentView = nil
        panel.close()
        self.panel = nil
    }

    // MARK: - Window Delegate
    func windowWillClose(_ notification: Notification) {
        guard let closingPanel = notification.object as? NSPanel, closingPanel === panel else { return }
        panel?.contentView = nil
        panel = nil
    }
}
