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
    fileprivate(set) var isVisible = false
    fileprivate(set) var window: NSPanel?
    fileprivate let frameAutosaveName = "MiMiNavigator.ConvertMediaWindow"
    fileprivate let defaultWidth: CGFloat = 420
    fileprivate let defaultHeight: CGFloat = 440

    private init() {}

    func open(file: CustomFile, panel: FavPanelSide, appState: AppState) {
        log.debug(#function)
        MediaInfoGetter().getMediaInfoToFile(
            url: file.urlValue,
            panelSide: panel,
            appState: appState
        )
    }
}

@MainActor
extension ConvertMediaCoord {

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

    func computeDefaultFrame() -> NSRect {
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

@MainActor
extension ConvertMediaCoord {

    func makeContentView(file: CustomFile, panel: FavPanelSide, appState: AppState) -> some View {
        ConvertMediaDialog(
            file: file,
            onConvert: { [weak self] preset, outputURL in
                self?.close()
                Task {
                    await CntMenuCoord.shared.performMediaConversion(
                        file: file,
                        targetFormat: preset.targetFormat,
                        outputURL: outputURL,
                        panel: panel,
                        appState: appState,
                        preset: preset
                    )
                }
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        .frame(minWidth: 380, minHeight: 360)
    }

    func makePanel() -> NSPanel {
        NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
    }

    func configure(panel: NSPanel) {
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 380, height: 360)
        panel.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(
            to: panel,
            systemImage: "arrow.triangle.2.circlepath",
            title: "Convert Media"
        )
        panel.toolbarStyle = .unified
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = false
        WindowPresentationPolicy.apply(.standalone, to: panel)
        panel.delegate = ConvertMediaWindowDelegate.shared
    }

    func restoreOrApplyDefaultFrame(for panel: NSPanel) {
        if !panel.setFrameUsingName(frameAutosaveName) {
            panel.setFrame(computeDefaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(frameAutosaveName)
    }
}
