// PanelDialogCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Generic coordinator for History and Favorites standalone NSPanel windows.
//              Centers dialogs over the main window on every open.

import AppKit
import SwiftUI

// MARK: - Dialog Kind

enum PanelDialogKind: String {
    case history = "MiMiNavigator.HistoryWindow"
    case favorites = "MiMiNavigator.FavoritesWindow"
}

// MARK: - PanelDialogCoordinator

@MainActor
final class PanelDialogCoordinator: NSObject, NSWindowDelegate {

    // MARK: - Shared instances
    static let history = PanelDialogCoordinator(
        kind: .history, title: "Navigation History", systemImage: "clock.arrow.circlepath", size: NSSize(width: 310, height: 768))
    static let favorites = PanelDialogCoordinator(
        kind: .favorites, title: "Favorites", systemImage: "sidebar.left", size: NSSize(width: 270, height: 864))

    // MARK: - State
    private(set) var isVisible = false
    private var panel: NSPanel?

    // MARK: - Config
    private let kind: PanelDialogKind
    private let windowTitle: String
    private let windowImage: String
    private let defaultSize: NSSize

    // MARK: - Init
    private init(kind: PanelDialogKind, title: String, systemImage: String, size: NSSize) {
        self.kind = kind
        self.windowTitle = title
        self.windowImage = systemImage
        self.defaultSize = size
    }

    // MARK: - Toggle
    func toggle<Content: View>(content: Content) {
        if isVisible { close() } else { open(content: content) }
    }

    // MARK: - Open
    func open<Content: View>(content: Content) {
        log.debug(#function)
        if let existing = panel, existing.isVisible {
            existing.setFrame(computeDefaultFrame(), display: true)
            existing.makeKeyAndOrderFront(nil)
            isVisible = true
            return
        }
        let hostingView = NSHostingView(
            rootView: content
        )
        let newPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newPanel.contentView = hostingView
        newPanel.isOpaque = false
        newPanel.backgroundColor = .windowBackgroundColor
        newPanel.isReleasedWhenClosed = false
        newPanel.minSize = NSSize(width: 260, height: 360)
        newPanel.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(to: newPanel, systemImage: windowImage, title: windowTitle)
        newPanel.toolbarStyle = .unified
        newPanel.animationBehavior = .default
        newPanel.isMovableByWindowBackground = false
        newPanel.hidesOnDeactivate = false
        newPanel.level = .normal
        newPanel.tabbingMode = .disallowed
        newPanel.autorecalculatesKeyViewLoop = true
        // Must be false — becomesKeyOnlyIfNeeded prevents Tab/Shift-Tab chain
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.delegate = self

        newPanel.setFrame(computeDefaultFrame(), display: true)

        newPanel.makeKeyAndOrderFront(nil)
        newPanel.recalculateKeyViewLoop()
        panel = newPanel
        isVisible = true
        log.info("[\(kind.rawValue)] Window opened")
    }

    // MARK: - Close
    func close() {
        panel?.close()
        isVisible = false
        log.info("[\(kind.rawValue)] Window closed")
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }

    // MARK: - Default Frame — centered on main window

    private func computeDefaultFrame() -> NSRect {
        let size = defaultSize
        if let mainWindow = NSApp.mainWindow {
            let mf = mainWindow.frame
            let x = mf.midX - size.width / 2
            let y = mf.midY - size.height / 2
            let screen = mainWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            let cx = max(screen.minX, min(x, screen.maxX - size.width))
            let cy = max(screen.minY, min(y, screen.maxY - size.height))
            return NSRect(origin: NSPoint(x: cx, y: cy), size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(
                x: sf.midX - size.width / 2,
                y: sf.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
        return NSRect(origin: .zero, size: size)
    }
}
