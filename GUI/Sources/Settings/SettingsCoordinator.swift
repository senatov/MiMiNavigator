// SettingsCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Settings as standalone floating NSPanel.
//   Same pattern as NetworkNeighborhoodCoordinator.
//   Opened via Files → Settings (⌘,)

import AppKit
import SwiftUI

// MARK: - SettingsCoordinator
@MainActor
@Observable
final class SettingsCoordinator {

    static let shared = SettingsCoordinator()

    private(set) var isVisible = false
    private var window: NSPanel?

    private let frameAutosaveName = "MiMiNavigator.SettingsWindow"
    private let defaultWidth: CGFloat  = 720
    private let defaultHeight: CGFloat = 540

    private init() {}

    // MARK: - Toggle
    func toggle() {
        isVisible ? close() : open()
    }

    // MARK: - Open
    func open() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            isVisible = true
            return
        }

        let contentView = SettingsWindowView(onDismiss: { [weak self] in self?.close() })
            .frame(minWidth: 600, minHeight: 440)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Settings"
        panel.contentView = NSHostingView(rootView: contentView)
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 600, height: 440)
        panel.titlebarAppearsTransparent = false
        panel.titleVisibility = .visible
        panel.toolbarStyle = .unified
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.tabbingMode = .disallowed

        if !panel.setFrameUsingName(frameAutosaveName) {
            panel.setFrame(computeDefaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(frameAutosaveName)
        panel.delegate = SettingsWindowDelegate.shared
        panel.makeKeyAndOrderFront(nil)

        window = panel
        isVisible = true
        log.info("[Settings] panel opened")
    }

    // MARK: - Close
    func close() {
        window?.close()
        isVisible = false
        log.info("[Settings] panel closed")
    }

    func windowDidClose() {
        isVisible = false
    }

    func bringToFront() {
        guard isVisible else { return }
        window?.orderFront(nil)
    }

    // MARK: - Default frame: centered over main window
    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)
        if let main = NSApp.mainWindow {
            let mf = main.frame
            return NSRect(origin: NSPoint(x: mf.midX - size.width / 2, y: mf.midY - size.height / 2), size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(origin: NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2), size: size)
        }
        return NSRect(origin: .zero, size: size)
    }
}

// MARK: - NSWindowDelegate
private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = SettingsWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            SettingsCoordinator.shared.windowDidClose()
        }
    }
}
