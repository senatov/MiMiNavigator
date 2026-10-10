import AppKit
import SwiftUI

@MainActor
final class FileOperationDiagnosticPresenter: NSObject, NSWindowDelegate {
    static let shared = FileOperationDiagnosticPresenter()

    private var panel: NSPanel?

    private override init() {}

    // MARK: - Show
    func show(_ info: FileOperationDiagnosticInfo) {
        WindowReplacement.close(panel)
        let panel = makePanel()
        panel.contentView = NSHostingView(
            rootView: FileOperationDiagnosticDialog(info: info) { [weak self] in
                self?.close()
            }
        )
        position(panel)
        WindowPresentationPolicy.presentStandalone(panel)
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
        AuxiliaryWindowFramePolicy.restoreOrCenter(
            panel,
            autosaveName: "MiMiNavigator.FileOperationDiagnosticWindow",
            designedSize: NSSize(width: 500, height: 280),
            relativeTo: WindowContextResolver.positioningWindow(excluding: panel)
        )
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
