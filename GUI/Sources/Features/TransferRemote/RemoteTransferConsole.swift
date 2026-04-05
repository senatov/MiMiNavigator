// RemoteTransferConsole.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Standalone console window for remote upload/download operations.
//   Opens as NSWindow (not child of main — survives main window moves/minimizes).
//   Auto-closes 2s after completion.
//   View content: TransferConsoleView (separate file).

import AppKit
import SwiftUI


// MARK: - RemoteTransferConsole

@MainActor
final class RemoteTransferConsole {

    static let shared = RemoteTransferConsole()
    private var window: NSWindow?

    private init() {}



    // MARK: - open

    func open(progress: RemoteTransferProgress) {
        log.debug(#function)
        if let w = window, w.isVisible {
            w.contentView = NSHostingView(rootView: TransferConsoleView(progress: progress))
            w.title = windowTitle(progress)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let view = TransferConsoleView(progress: progress)
        let hosting = NSHostingView(rootView: view)
        hosting.setFrameSize(NSSize(width: 560, height: 420))
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title           = windowTitle(progress)
        w.contentView     = hosting
        w.minSize         = NSSize(width: 420, height: 280)
        w.isReleasedWhenClosed = false
        w.level           = .floating
        w.center()
        w.makeKeyAndOrderFront(nil)
        self.window = w
        observeCompletion(progress: progress, window: w)
        log.info("[TransferConsole] opened for \(progress.direction.title)")
    }



    // MARK: - close

    func close() {
        window?.close()
        window = nil
    }



    // MARK: - Private

    private func windowTitle(_ p: RemoteTransferProgress) -> String {
        "\(p.direction.title) — \(p.serverLabel)"
    }



    private func observeCompletion(progress: RemoteTransferProgress, window: NSWindow) {
        Task {
            while !progress.isCompleted && !progress.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
            }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                window.close()
                if self.window === window { self.window = nil }
            }
        }
    }
}
