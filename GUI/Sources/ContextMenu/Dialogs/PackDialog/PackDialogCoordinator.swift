// PackDialogCoordinator.swift
// MiMiNavigator
//
// Created by Claude on 14.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Create Archive as a standalone NSPanel.
//   - Non-modal, glass-style, movable, resizable
//   - Persists frame position via frameAutosaveName
//   - hidesOnDeactivate=false: stays visible when app loses focus
//   - Rises to front via AppDelegate.applicationDidBecomeActive
//   - Mirrors NetworkNeighborhoodCoordinator behavior

import AppKit
import FileModelKit
import SwiftUI


// MARK: - PackDialogCoordinator
@MainActor
@Observable
final class PackDialogCoordinator {

    static let shared = PackDialogCoordinator()
    private(set) var isVisible = false
    private var window: NSPanel?
    private let frameAutosaveName = "MiMiNavigator.PackDialogWindow"
    private let defaultWidth: CGFloat = 460
    private let defaultHeight: CGFloat = 520
    private init() {}


    // MARK: - Open
    func open(
        mode: PackDialogMode,
        files: [CustomFile],
        sourcePanel: FavPanelSide,
        appState: AppState,
        onPack: @escaping (String, ArchiveFormat, URL, Bool, CompressionLevel, String?) -> Void
    ) {
        log.debug("[PackPanel] \(#function) mode=\(mode) files=\(files.count)")
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            isVisible = true
            return
        }
        let contentView = PackDialog(
            mode: mode,
            files: files,
            sourcePanel: sourcePanel,
            onPack: { [weak self] name, fmt, dest, del, level, pwd in
                onPack(name, fmt, dest, del, level, pwd)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        .environment(appState)
        .frame(minWidth: 400, minHeight: 360)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        configurePanel(panel, contentView: contentView)
        if !panel.setFrameUsingName(frameAutosaveName) {
            panel.setFrame(computeDefaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(frameAutosaveName)
        panel.delegate = PackWindowDelegate.shared
        panel.makeKeyAndOrderFront(nil)
        window = panel
        isVisible = true
        log.info("[PackPanel] opened")
    }


    // MARK: - Configure Panel
    private func configurePanel<Content: View>(_ panel: NSPanel, contentView: Content) {
        panel.contentView = NSHostingView(rootView: contentView)
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 400, height: 360)
        PanelTitleHelper.applyIconTitle(
            to: panel,
            systemImage: "archivebox",
            title: "Create Archive"
        )
        panel.toolbarStyle = .unified
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .normal
        panel.tabbingMode = .disallowed
    }


    // MARK: - Close
    func close() {
        guard let window else {
            isVisible = false
            return
        }
        window.close()
        isVisible = false
        log.info("[PackPanel] closed")
    }


    // MARK: - Called by delegate
    func windowDidClose() {
        isVisible = false
        window = nil
    }


    // MARK: - Raise to front (called when main window becomes key)
    func bringToFront() {
        guard isVisible else { return }
        window?.orderFront(nil)
    }


    // MARK: - Default frame: centered over main window
    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)
        if let main = NSApp.mainWindow {
            let mf = main.frame
            let x = mf.midX - size.width / 2
            let y = mf.midY - size.height / 2
            return NSRect(origin: NSPoint(x: x, y: y), size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(
                origin: NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2),
                size: size
            )
        }
        return NSRect(origin: .zero, size: size)
    }
}



// MARK: - NSWindowDelegate
private final class PackWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = PackWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            PackDialogCoordinator.shared.windowDidClose()
        }
    }
}
