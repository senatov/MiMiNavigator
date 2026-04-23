// ToolbarCustCoord.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Toolbar Customize as standalone NSPanel.
//   Same pattern as SettingsCoordinator — proper NSWindowDelegate, frame autosave.

import AppKit
import SwiftUI

// MARK: - Toolbar Customize Coordinator
@MainActor
@Observable
final class ToolbarCustomizeCoordinator {

    static let shared = ToolbarCustomizeCoordinator()

    private(set) var isVisible = false
    private var window: NSPanel?
    private var mainWindowObserver: NSObjectProtocol?
    private var isClosing = false

    private let frameAutosaveName = "MiMiNavigator.ToolbarCustomizePanel"
    private let defaultWidth: CGFloat = 600
    private let defaultHeight: CGFloat = 645

    private init() {}


    func toggle() {
        isVisible ? close() : show()
    }


    func show() {
        guard !isClosing else { return }
        log.debug("[ToolbarCustomize] show() invoked")
        let sourceMainWindow = currentPrimaryWindow(excluding: window)
        if let existing = window, existing.isVisible {
            present(existing, relativeTo: sourceMainWindow)
            isVisible = true
            return
        }
        let contentView = ToolbarCustomizeRootView(onDismiss: { [weak self] in self?.close() })
            .frame(minWidth: 440, minHeight: 460)
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: contentView)
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 440, height: 460)
        panel.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(to: panel, systemImage: "wrench.adjustable", title: "Customize Toolbar")
        panel.toolbarStyle = .unified
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.tabbingMode = .disallowed
        panel.hasShadow = true
        panel.collectionBehavior.insert(.moveToActiveSpace)
        panel.backgroundColor = NSColor(DialogColors.base)
        if !panel.setFrameUsingName(frameAutosaveName) {
            panel.setFrame(computeDefaultFrame(), display: true)
        }
        panel.setFrameAutosaveName(frameAutosaveName)
        panel.delegate = ToolbarCustWindowDelegate.shared
        installReactivationObservers()
        self.window = panel
        isVisible = true
        present(panel, relativeTo: sourceMainWindow)
        panel.makeFirstResponder(panel.contentView)
        log.info("[ToolbarCustomize] opened ✓")
    }


    func close() {
        log.debug("[ToolbarCustomize] close() invoked")
        guard !isClosing else { return }
        isClosing = true
        removeReactivationObservers()
        isVisible = false
        let panel = window
        window = nil
        panel?.close()
        log.info("[ToolbarCustomize] closed ✓")
    }

    func bringToFront() {
        guard !isClosing else { return }
        guard let window, isVisible else { return }
        present(window, relativeTo: currentPrimaryWindow(excluding: window))
    }

    func windowDidClose() {
        removeReactivationObservers()
        isClosing = false
        isVisible = false
    }


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

    private func installReactivationObservers() {
        removeReactivationObservers()
        mainWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let observedWindow = notification.object as? NSWindow else { return }
            Task { @MainActor [weak self] in
                guard let self,
                      let panel = self.window,
                      observedWindow != panel,
                      observedWindow.isVisible,
                      observedWindow.isMainWindow,
                      NSApp.isActive,
                      self.isVisible else {
                    return
                }
                self.orderAbove(panel, relativeTo: observedWindow)
            }
        }
    }

    private func removeReactivationObservers() {
        if let mainWindowObserver {
            NotificationCenter.default.removeObserver(mainWindowObserver)
            self.mainWindowObserver = nil
        }
    }

    private func currentPrimaryWindow(excluding panel: NSWindow?) -> NSWindow? {
        if let main = NSApp.mainWindow, main != panel, main.isVisible {
            return main
        }
        if let key = NSApp.keyWindow, key != panel, key.isVisible {
            return key
        }
        return NSApp.windows.first { window in
            window != panel && window.isVisible && !window.isKind(of: NSPanel.self)
        }
    }

    private func orderAbove(_ panel: NSPanel, relativeTo window: NSWindow) {
        if panel.windowNumber == 0 {
            panel.orderFrontRegardless()
        } else {
            panel.order(.above, relativeTo: window.windowNumber)
        }
    }

    private func present(_ panel: NSPanel, relativeTo window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            orderAbove(panel, relativeTo: window)
        } else {
            panel.orderFrontRegardless()
        }

        panel.makeKeyAndOrderFront(nil)

        // Re-assert z-order on the next main turn, after right-click menu tracking settles.
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, self.window === panel, self.isVisible else { return }
            if let window = self.currentPrimaryWindow(excluding: panel) {
                self.orderAbove(panel, relativeTo: window)
            } else {
                panel.orderFrontRegardless()
            }
            panel.makeKeyAndOrderFront(nil)
        }
    }
}


// MARK: - NSWindowDelegate
private final class ToolbarCustWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = ToolbarCustWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            ToolbarCustomizeCoordinator.shared.windowDidClose()
        }
    }
}
