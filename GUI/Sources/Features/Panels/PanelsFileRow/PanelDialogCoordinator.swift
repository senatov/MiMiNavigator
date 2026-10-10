// PanelDialogCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Generic coordinator for History and Favorites standalone NSPanel windows.
//              Restores dialog position and size for the current display layout.

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
        kind: .history, title: "Navigation History", systemImage: "clock.arrow.circlepath", size: NSSize(width: 558, height: 768))
    static let favorites = PanelDialogCoordinator(
        kind: .favorites, title: "Favorites", systemImage: "sidebar.left", size: NSSize(width: 486, height: 864))

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
        open(content: content)
    }

    // MARK: - Open
    func open<Content: View>(content: Content) {
        log.debug(#function)
        WindowReplacement.close(panel)
        panel = nil
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
        WindowPresentationPolicy.apply(.standalone, to: newPanel)
        newPanel.collectionBehavior.insert(.fullScreenAuxiliary)
        newPanel.autorecalculatesKeyViewLoop = true
        // Must be false — becomesKeyOnlyIfNeeded prevents Tab/Shift-Tab chain
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.delegate = self
        AuxiliaryWindowFramePolicy.restoreOrCenter(
            newPanel,
            autosaveName: kind.rawValue,
            designedSize: defaultSize
        )
        presentAboveMain(newPanel)
        newPanel.recalculateKeyViewLoop()
        panel = newPanel
        isVisible = true
        log.info("[\(kind.rawValue)] Window opened")
    }

    // MARK: - Close
    func close() {
        panel?.close()
        panel = nil
        isVisible = false
        log.info("[\(kind.rawValue)] Window closed")
    }

    // MARK: - Bring to Front
    func bringToFront() {
        guard let panel, panel.isVisible else { return }
        WindowPresentationPolicy.raiseStandalone(panel)
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        panel = nil
        isVisible = false
    }

    // MARK: - Present Above Main Window
    private func presentAboveMain(_ panel: NSPanel) {
        WindowPresentationPolicy.presentStandalone(panel)
    }

}
