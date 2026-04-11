// ConvertMediaCoord.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Convert Media as a standalone NSPanel.
//   Mirrors NetworkNeighborhoodCoordinator: movable, resizable, persists position.

import AppKit
import FileModelKit
import SwiftUI

@MainActor
@Observable
final class ConvertMediaCoord {

    static let shared = ConvertMediaCoord()
    private(set) var isVisible = false
    private var window: NSPanel?
    private let frameAutosaveName = "MiMiNavigator.ConvertMediaWindow"
    private let defaultWidth: CGFloat = 420
    private let defaultHeight: CGFloat = 440
    private init() {}

    func open(file: CustomFile, panel: FavPanelSide, appState: AppState) {
        log.debug(#function)
        if let existing = window, existing.isVisible {
            existing.close()
        }
        let contentView = ConvertMediaDialog(
            file: file,
            onConvert: { [weak self] targetFormat, outputURL in
                self?.close()
                Task {
                    await CntMenuCoord.shared.performMediaConversion(
                        file: file, targetFormat: targetFormat,
                        outputURL: outputURL, panel: panel, appState: appState)
                }
            },
            onCancel: { [weak self] in self?.close() }
        )
        .frame(minWidth: 380, minHeight: 360)

        let nsPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        nsPanel.contentView = NSHostingView(rootView: contentView)
        nsPanel.isReleasedWhenClosed = false
        nsPanel.minSize = NSSize(width: 380, height: 360)
        nsPanel.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(
            to: nsPanel, systemImage: "arrow.triangle.2.circlepath",
            title: "Convert Media")
        nsPanel.toolbarStyle = .unified
        nsPanel.animationBehavior = .utilityWindow
        nsPanel.isMovableByWindowBackground = false
        nsPanel.hidesOnDeactivate = false
        nsPanel.level = .normal
        nsPanel.tabbingMode = .disallowed
        nsPanel.delegate = ConvertMediaWindowDelegate.shared
        if !nsPanel.setFrameUsingName(frameAutosaveName) {
            nsPanel.setFrame(computeDefaultFrame(), display: true)
        }
        nsPanel.setFrameAutosaveName(frameAutosaveName)
        nsPanel.makeKeyAndOrderFront(nil)
        window = nsPanel
        isVisible = true
        log.info("[ConvertMedia] panel opened for '\(file.nameStr)'")
    }

    func close() {
        guard let window else {
            isVisible = false
            return
        }
        window.close()
        isVisible = false
        log.info("[ConvertMedia] panel closed")
    }

    func windowDidClose() {
        isVisible = false
        window = nil
    }

    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)
        if let main = NSApp.mainWindow {
            let mf = main.frame
            return NSRect(
                origin: NSPoint(x: mf.midX - size.width / 2, y: mf.midY - size.height / 2),
                size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(
                origin: NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2),
                size: size)
        }
        return NSRect(origin: .zero, size: size)
    }
}

private final class ConvertMediaWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = ConvertMediaWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            ConvertMediaCoord.shared.windowDidClose()
        }
    }
}
