// ToolbarCustCoord.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Toolbar Customize as standalone NSPanel.
//   Same pattern as SettingsCoordinator — proper NSWindowDelegate, size persistence.

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

    private let sizeDefaultsKey = "MiMiNavigator.ToolbarCustomizePanelSize"
    private let toolbarHeight: CGFloat = 52
    private let panelMargin: CGFloat = 12
    private let defaultWidth: CGFloat = 1_200
    private let defaultHeight: CGFloat = 645

    private init() {}


    func toggle() {
        isVisible ? close() : show()
    }


    func show(anchorScreenPoint: NSPoint? = nil) {
        guard !isClosing else { return }
        log.debug("[ToolbarCustomize] show() invoked")
        let sourceMainWindow = currentPrimaryWindow(excluding: window)
        if let existing = window, existing.isVisible {
            position(existing, near: anchorScreenPoint, relativeTo: sourceMainWindow)
            present(existing, relativeTo: sourceMainWindow)
            isVisible = true
            return
        }
        let contentView = ToolbarCustomizeRootView(onDismiss: { [weak self] in self?.close() })
            .frame(minWidth: 440, minHeight: 460)
        let initialFrame = frame(near: anchorScreenPoint, relativeTo: sourceMainWindow, requestedSize: restoredSize())
        let panel = ToolbarCustomizePanel(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentView = ToolbarCustomizeHostingView(rootView: contentView)
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 440, height: 460)
        panel.titlebarAppearsTransparent = false
        panel.titleVisibility = .visible
        panel.title = "Customize Toolbar"
        PanelTitleHelper.applyIconTitle(to: panel, systemImage: "wrench.adjustable", title: "Customize Toolbar")
        panel.onCloseButtonClick = { [weak self] in
            log.debug("[ToolbarCustomize] titlebar close routed to coordinator")
            self?.close()
        }
        panel.toolbarStyle = .unified
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.tabbingMode = .disallowed
        panel.becomesKeyOnlyIfNeeded = false
        panel.autorecalculatesKeyViewLoop = true
        panel.hasShadow = true
        panel.collectionBehavior.insert(.moveToActiveSpace)
        panel.backgroundColor = NSColor(DialogColors.base)
        panel.delegate = ToolbarCustWindowDelegate.shared
        installReactivationObservers()
        self.window = panel
        isVisible = true
        present(panel, relativeTo: sourceMainWindow)
        panel.recalculateKeyViewLoop()
        log.info("[ToolbarCustomize] opened ✓")
    }


    func close() {
        log.debug("[ToolbarCustomize] close() invoked")
        guard !isClosing else { return }
        isClosing = true
        removeReactivationObservers()
        isVisible = false
        let panel = window
        if let panel {
            saveSize(panel.frame.size)
            (panel as? ToolbarCustomizePanel)?.onCloseButtonClick = nil
        }
        window = nil
        panel?.orderOut(nil)
        isClosing = false
        log.info("[ToolbarCustomize] closed ✓")
    }

    func bringToFront() {
        guard !isClosing else { return }
        guard let window, isVisible else { return }
        present(window, relativeTo: currentPrimaryWindow(excluding: window))
    }

    func windowDidClose() {
        if let window {
            saveSize(window.frame.size)
        }
        removeReactivationObservers()
        isClosing = false
        isVisible = false
    }

    func windowDidResize() {
        guard let window else { return }
        saveSize(window.frame.size)
    }


    private func computeDefaultFrame() -> NSRect {
        frame(near: nil, relativeTo: currentPrimaryWindow(excluding: window), requestedSize: restoredSize())
    }

    private func position(_ panel: NSPanel, near anchorScreenPoint: NSPoint?, relativeTo window: NSWindow?) {
        panel.setFrame(frame(near: anchorScreenPoint, relativeTo: window, requestedSize: panel.frame.size), display: true)
    }

    private func frame(near anchorScreenPoint: NSPoint?, relativeTo window: NSWindow?, requestedSize: NSSize) -> NSRect {
        let bounds = constrainedMainWindowFrame(relativeTo: window)
        let availableWidth = max(440, bounds.width - 2 * panelMargin)
        let availableHeight = max(460, bounds.height - toolbarHeight - 2 * panelMargin)
        let size = NSSize(
            width: min(max(440, requestedSize.width), availableWidth),
            height: min(max(460, requestedSize.height), availableHeight)
        )
        let fallbackAnchor = NSPoint(x: bounds.midX, y: bounds.maxY - toolbarHeight)
        let anchor = anchorScreenPoint ?? fallbackAnchor
        let toolbarBottomY = bounds.maxY - toolbarHeight
        let preferredTopY = min(anchor.y - panelMargin, toolbarBottomY - panelMargin)
        let preferredOrigin = NSPoint(
            x: anchor.x - size.width / 2,
            y: preferredTopY - size.height
        )
        let minX = bounds.minX + panelMargin
        let maxX = max(minX, bounds.maxX - size.width - panelMargin)
        let minY = bounds.minY + panelMargin
        let maxY = max(minY, toolbarBottomY - size.height - panelMargin)
        let x = min(max(preferredOrigin.x, minX), maxX)
        let y = min(max(preferredOrigin.y, minY), maxY)
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func constrainedMainWindowFrame(relativeTo window: NSWindow?) -> NSRect {
        if let window {
            return window.frame
        }
        if let main = NSApp.mainWindow {
            return main.frame
        }
        if let screen = NSScreen.main {
            return screen.visibleFrame
        }
        return NSRect(origin: .zero, size: NSSize(width: defaultWidth, height: defaultHeight + toolbarHeight))
    }

    private func restoredSize() -> NSSize {
        guard let string = UserDefaults.standard.string(forKey: sizeDefaultsKey) else {
            return NSSize(width: defaultWidth, height: defaultHeight)
        }
        let parts = string.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else {
            return NSSize(width: defaultWidth, height: defaultHeight)
        }
        return NSSize(width: max(440, parts[0]), height: max(460, parts[1]))
    }

    private func saveSize(_ size: NSSize) {
        let width = Int(max(440, size.width).rounded())
        let height = Int(max(460, size.height).rounded())
        UserDefaults.standard.set("\(width)x\(height)", forKey: sizeDefaultsKey)
        log.debug("[ToolbarCustomize] size saved \(width)x\(height)")
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

        panel.makeKeyAndOrderFront(nil)

        // Re-assert key status on the next main turn, after right-click menu tracking settles.
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, self.window === panel, self.isVisible else { return }
            panel.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Toolbar Customize Panel
private final class ToolbarCustomizePanel: NSPanel {
    var onCloseButtonClick: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            log.debug("[ToolbarCustomize] panel leftMouseDown key=\(isKeyWindow) loc=\(event.locationInWindow)")
            if isCloseButtonClick(event) {
                log.debug("[ToolbarCustomize] titlebar close hit")
                onCloseButtonClick?()
                return
            }
            if !isKeyWindow {
                log.debug("[ToolbarCustomize] making panel key before forwarding click")
                makeKey()
            }
        }
        super.sendEvent(event)
    }

    private func isCloseButtonClick(_ event: NSEvent) -> Bool {
        guard let closeButton = standardWindowButton(.closeButton), !closeButton.isHidden else {
            return false
        }
        let pointInButton = closeButton.convert(event.locationInWindow, from: nil)
        return closeButton.bounds.contains(pointInButton)
    }
}

// MARK: - First Mouse Hosting View
private final class ToolbarCustomizeHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}


// MARK: - NSWindowDelegate
private final class ToolbarCustWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = ToolbarCustWindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        log.debug("[ToolbarCustomize] windowShouldClose routed to coordinator")
        Task { @MainActor in
            ToolbarCustomizeCoordinator.shared.close()
        }
        return false
    }

    func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            ToolbarCustomizeCoordinator.shared.windowDidResize()
        }
    }

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            ToolbarCustomizeCoordinator.shared.windowDidClose()
        }
    }
}
