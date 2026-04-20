import AppKit
import SwiftUI

@MainActor
final class FileOperationDiagnosticPresenter {
    static let shared = FileOperationDiagnosticPresenter()

    private init() {}

    func show(_ info: FileOperationDiagnosticInfo) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = false
        panel.toolbarStyle = .unified
        panel.hidesOnDeactivate = false
        panel.tabbingMode = .disallowed
        panel.level = .modalPanel
        PanelTitleHelper.applyIconTitle(to: panel, systemImage: "exclamationmark.triangle", title: "File Operation Error")

        panel.contentView = NSHostingView(
            rootView: FileOperationDiagnosticDialog(info: info) {
                NSApp.stopModal()
                panel.orderOut(nil)
                panel.close()
            }
        )

        if let main = NSApp.mainWindow {
            let frame = main.frame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.midY - panel.frame.height / 2
            ))
        } else {
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: panel)
    }
}
