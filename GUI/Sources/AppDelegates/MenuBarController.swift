// MenuBarController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Native menu bar item for opening MiMiNavigator and common actions.

import AppKit
import SwiftUI

// MARK: - Menu Bar Controller
@MainActor final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var diagnosticLogOffset: UInt64 = 0

    // MARK: - Install
    func install() {
        guard statusItem == nil else { return }
        diagnosticLogOffset = MenuBarDiagnostics.currentLogOffset()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            log.error("[MenuBar] status item button unavailable")
            return
        }
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.image = makeStatusImage()
        button.toolTip = "MiMiNavigator"
        button.setAccessibilityLabel("Show MiMiNavigator")
        item.menu = nil
        item.isVisible = true
        statusItem = item
        log.info("[MenuBar] native status item installed visible=\(item.isVisible)")
        DispatchQueue.main.async { [weak self] in
            self?.logStatusItemState()
        }
    }

    // MARK: - Status Item Actions
    @objc private func handleStatusItemClick() {
        guard NSApp.currentEvent?.type != .rightMouseUp else {
            toggleStatusPopover()
            return
        }
        closeStatusPopover()
        toggleApplicationVisibility()
    }

    private func toggleApplicationVisibility() {
        if let window = existingMainWindow,
           window.isVisible,
           !window.isMiniaturized,
           window.isKeyWindow,
           NSApp.isActive
        {
            window.miniaturize(nil)
            log.info("[MenuBar] minimized main window to Dock")
            return
        }
        showApplication()
    }

    private func showApplication() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let window = existingMainWindow {
            raise(window)
        } else {
            NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
        }
        DispatchQueue.main.async { [weak self] in self?.raiseExistingMainWindow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.raiseExistingMainWindow() }
    }

    private func toggleStatusPopover() {
        guard let button = statusItem?.button else { return }
        if statusPopover?.isShown == true {
            closeStatusPopover()
            return
        }
        let appState = AppStateProvider.shared
        let panel = appState?.focusedPanel
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 336, height: 470)
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView(
            version: AppBuildInfo.versionString(),
            memory: memoryLabel,
            activePanel: panel == .right ? "Right" : "Left",
            currentPath: panel.flatMap { appState?.path(for: $0) } ?? NSHomeDirectory(),
            issues: MenuBarDiagnostics.issues(since: diagnosticLogOffset),
            onShow: { [weak self] in self?.performPopoverAction { self?.showApplication() } },
            onFind: { [weak self] in self?.performPopoverAction { self?.openFindFiles() } },
            onConnect: { [weak self] in self?.performPopoverAction { self?.openConnectToServer() } },
            onSettings: { [weak self] in self?.performPopoverAction { self?.openSettings() } },
            onQuit: { [weak self] in self?.performPopoverAction { self?.quitApplication() } }
        ))
        statusPopover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func performPopoverAction(_ action: () -> Void) {
        closeStatusPopover()
        action()
    }

    private func closeStatusPopover() {
        statusPopover?.performClose(nil)
        statusPopover = nil
    }

    private func openFindFiles() {
        showApplication()
        guard let appState = AppStateProvider.shared else { return }
        let panel = appState.focusedPanel
        FindFilesCoordinator.shared.appState = appState
        FindFilesCoordinator.shared.open(searchPath: appState.path(for: panel))
    }

    private func openConnectToServer() {
        showApplication()
        ConnectToServerCoordinator.shared.open()
    }

    private func openSettings() {
        showApplication()
        SettingsCoordinator.shared.open()
    }

    private func quitApplication() {
        log.info("[MenuBar] quit requested")
        NSApp.terminate(nil)
    }

    // MARK: - Status Image
    private func makeStatusImage() -> NSImage? {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "MiMiNavigator")
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        return image
    }

    private var memoryLabel: String {
        MemoryDiagnostics.wholeMemoryLabel(bytes: MemoryDiagnostics.capture().footprintBytes)
    }

    private var existingMainWindow: NSWindow? {
        let windows = NSApp.windows.filter { !($0 is NSPanel) && $0.styleMask.contains(.titled) }
        return windows.first { $0.identifier?.rawValue.hasPrefix("main-AppWindow") == true }
            ?? windows.first { $0.isMiniaturized || $0.isVisible }
    }

    // MARK: - Raise Main Window
    private func raiseExistingMainWindow() {
        guard let window = existingMainWindow else {
            log.error("[MenuBar] main window unavailable after activation")
            return
        }
        raise(window)
    }

    private func raise(_ window: NSWindow) {
        let wasMiniaturized = window.isMiniaturized
        if wasMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.arrangeInFront(nil)
        log.info(
            "[MenuBar] raised main window id='\(window.identifier?.rawValue ?? "nil")' minimized=\(wasMiniaturized) visible=\(window.isVisible)"
        )
    }

    // MARK: - Log State
    private func logStatusItemState() {
        guard let item = statusItem, let button = item.button else {
            log.error("[MenuBar] status item lost after installation")
            return
        }
        let frame = button.window?.frame ?? .zero
        log.info("[MenuBar] status item ready visible=\(item.isVisible) windowVisible=\(button.window?.isVisible == true) frame=\(NSStringFromRect(frame))")
    }
}
