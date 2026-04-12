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
    fileprivate var mainWindowObserver: NSObjectProtocol?

    private init() {}

    func open(file: CustomFile, panel: FavPanelSide, appState: AppState) {
        log.debug(#function)
        if let existing = window, existing.isVisible {
            existing.close()
        }
        let panelView = makeContentView(file: file, panel: panel, appState: appState)
        let panelWindow = makePanel()
        configure(panel: panelWindow)
        panelWindow.contentView = NSHostingView(rootView: panelView)
        restoreOrApplyDefaultFrame(for: panelWindow)
        panelWindow.makeKeyAndOrderFront(nil)
        window = panelWindow
        isVisible = true
        installReactivationObservers()
        log.info("[ConvertMedia] panel opened for '\(file.nameStr)'")
    }
}

@MainActor
extension ConvertMediaCoord {

    func close() {
        guard let window else {
            isVisible = false
            return
        }
        removeReactivationObservers()
        window.close()
        isVisible = false
        log.info("[ConvertMedia] panel closed")
    }

    func windowDidClose() {
        removeReactivationObservers()
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

    func installReactivationObservers() {
        removeReactivationObservers()
        let center = NotificationCenter.default
        mainWindowObserver = center.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let observedWindow = notification.object as? NSWindow,
                  observedWindow != self.window,
                  observedWindow.className != "NSStatusBarWindow",
                  observedWindow.isVisible,
                  observedWindow.isMainWindow,
                  observedWindow.isKeyWindow else {
                return
            }
            self.bringPanelInFrontOfMainWindowIfNeeded(relativeTo: observedWindow)
        }
    }

    func removeReactivationObservers() {
        let center = NotificationCenter.default
        if let mainWindowObserver {
            center.removeObserver(mainWindowObserver)
            self.mainWindowObserver = nil
        }
    }

    func bringPanelInFrontOfMainWindowIfNeeded(relativeTo mainWindow: NSWindow) {
        guard isVisible,
              let panelWindow = window,
              panelWindow.isVisible,
              mainWindow != panelWindow,
              NSApp.isActive else {
            return
        }
        panelWindow.order(.above, relativeTo: mainWindow.windowNumber)
    }
}

@MainActor
extension ConvertMediaCoord {

    func makeContentView(file: CustomFile, panel: FavPanelSide, appState: AppState) -> some View {
        ConvertMediaDialog(
            file: file,
            onConvert: { [weak self] targetFormat, outputURL in
                self?.close()
                Task {
                    await CntMenuCoord.shared.performMediaConversion(
                        file: file,
                        targetFormat: targetFormat,
                        outputURL: outputURL,
                        panel: panel,
                        appState: appState
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
        panel.hidesOnDeactivate = false
        panel.level = .normal
        panel.tabbingMode = .disallowed
        panel.delegate = ConvertMediaWindowDelegate.shared
    }

    func restoreOrApplyDefaultFrame(for panel: NSPanel) {
        if !panel.setFrameUsingName(frameAutosaveName) {
            panel.setFrame(computeDefaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(frameAutosaveName)
    }
}
