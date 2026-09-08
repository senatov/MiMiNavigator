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
    private var statusVerificationTask: Task<Void, Never>?
    private var didRecreateStatusItem = false

    // MARK: - Install
    func install() {
        guard statusItem == nil else { return }
        diagnosticLogOffset = MenuBarDiagnostics.currentLogOffset()
        createStatusItem()
        verifyStatusItem()
    }

    // MARK: - Create Status Item
    private func createStatusItem() {
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
        button.setAccessibilityLabel("Show or minimize MiMiNavigator")
        item.menu = nil
        item.isVisible = true
        statusItem = item
        log.info("[MenuBar] native status item installed visible=\(item.isVisible)")
    }

    // MARK: - Verify Status Item
    func verifyStatusItem() {
        guard statusVerificationTask == nil else { return }
        statusVerificationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.statusVerificationTask = nil }
            for attempt in 1...4 {
                do { try await Task.sleep(for: .seconds(attempt == 1 ? 0.5 : 1.5)) }
                catch { return }
                if self.logStatusItemState(attempt: attempt) { return }
                guard attempt < 4 else { break }
                if attempt == 2 && !self.didRecreateStatusItem {
                    self.didRecreateStatusItem = true
                    self.closeStatusPopover()
                    if let item = self.statusItem { NSStatusBar.system.removeStatusItem(item) }
                    self.statusItem = nil
                    log.warning("[MenuBar] recreating status item after persistent invalid geometry")
                    self.createStatusItem()
                } else {
                    self.statusItem?.button?.image = self.makeStatusImage()
                    self.statusItem?.length = NSStatusItem.squareLength
                    self.statusItem?.isVisible = true
                }
            }
            log.error("[MenuBar] status item layout unconfirmed after delayed checks; recovery exhausted, inspect menu bar space and system visibility")
        }
    }

    // MARK: - Status Item Actions
    @objc private func handleStatusItemClick() {
        let eventType = NSApp.currentEvent?.type
        log.info("[MenuBar] status item click type='\(String(describing: eventType))'")
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
            return
        } else {
            let requested = MainWindowPresenter.shared.open()
            if !requested {
                let handled = NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
                log.warning("[MenuBar] AppKit newWindow fallback handled=\(handled)")
            }
        }
        scheduleMainWindowRaise(after: 0.05, remainingAttempts: 4)
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
        popover.contentSize = NSSize(width: 344, height: 476)
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
        image?.size = NSSize(width: 19, height: 19)
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
    private func scheduleMainWindowRaise(after delay: TimeInterval, remainingAttempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if let window = self.existingMainWindow {
                self.raise(window)
                return
            }
            guard remainingAttempts > 1 else {
                log.error("[MenuBar] main window unavailable after SwiftUI open request")
                return
            }
            self.scheduleMainWindowRaise(after: delay * 2, remainingAttempts: remainingAttempts - 1)
        }
    }

    private func raise(_ window: NSWindow) {
        let wasMiniaturized = window.isMiniaturized
        let originalCollectionBehavior = window.collectionBehavior
        if wasMiniaturized { window.deminiaturize(nil) }
        if !originalCollectionBehavior.contains(.canJoinAllSpaces) {
            window.collectionBehavior.insert(.moveToActiveSpace)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak window] in
            guard let window else { return }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak window] in
            guard let window else { return }
            window.collectionBehavior = originalCollectionBehavior
            log.info("[MenuBar] restored main window Space behavior")
        }
        let screenFrame = window.screen?.visibleFrame ?? .zero
        log.info(
            "[MenuBar] raised main window id='\(window.identifier?.rawValue ?? "nil")' minimized=\(wasMiniaturized) visible=\(window.isVisible) key=\(window.isKeyWindow) occlusion=\(window.occlusionState.rawValue) frame=\(NSStringFromRect(window.frame)) screen=\(NSStringFromRect(screenFrame))"
        )
    }

    // MARK: - Log State
    private func logStatusItemState(attempt: Int) -> Bool {
        guard let item = statusItem, let button = item.button else {
            log.error("[MenuBar] status item lost after installation")
            return false
        }
        let frame = button.window?.frame ?? .zero
        let screens = NSScreen.screens.map(\.frame)
        let hasGeometry = frame.width > 0 && frame.height > 0
            && screens.contains { $0.contains(NSPoint(x: frame.midX, y: frame.midY)) }
        let layoutValid = item.isVisible && button.window?.isVisible == true && button.image != nil && hasGeometry
        let screenDescription = screens.map { NSStringFromRect($0) }.joined(separator: ", ")
        log.info("[MenuBar] status item check attempt=\(attempt) layoutValid=\(layoutValid) visible=\(item.isVisible) windowVisible=\(button.window?.isVisible == true) image=\(button.image != nil) frame=\(NSStringFromRect(frame)) screens=[\(screenDescription)] active=\(NSApp.isActive)")
        return layoutValid
    }
}
