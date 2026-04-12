//
//  File.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI


@MainActor
extension ConvertMediaDialog {
    func cleanupWindowState() {
        frameSaveWorkItem?.cancel()
        frameSaveWorkItem = nil
        removeWindowObservers()
    }


    func configureHostingWindowIfNeeded() {
        Task { @MainActor in
            guard let window = resolveHostingWindow() else { return }
            let windowNumber = window.windowNumber
            guard configuredWindowNumber != windowNumber else { return }
            configuredWindowNumber = windowNumber
            removeWindowObservers()
            configure(window: window)
            restoreFrameIfNeeded(for: window)
            bringWindowToFront(window)
            installWindowObservers(for: window)
        }
    }


    func resolveHostingWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow
    }


    func configure(window: NSWindow) {
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: Layout.minWidth, height: Layout.minHeight)
        window.level = .floating
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.isMovableByWindowBackground = true
    }



    func restoreFrameIfNeeded(for window: NSWindow) {
        guard let storedFrame = loadStoredFrame() else { return }
        let frame = NSRect(
            x: storedFrame.x,
            y: storedFrame.y,
            width: max(Layout.minWidth, storedFrame.width),
            height: max(Layout.minHeight, storedFrame.height)
        )
        window.setFrame(frame, display: true)
    }



    func bringWindowToFront(_ window: NSWindow) {
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }


    func installWindowObservers(for window: NSWindow) {
        let center = NotificationCenter.default
        let moveToken = addWindowObserver(center: center, name: WindowState.frameChangedNotification, window: window) {
            scheduleFrameSave(for: window)
        }
        let resizeToken = addWindowObserver(center: center, name: WindowState.resizeChangedNotification, window: window) {
            scheduleFrameSave(for: window)
        }
        let becomeMainToken = addWindowObserver(center: center, name: WindowState.becomeMainNotification, window: window) {
            bringWindowToFront(window)
        }
        windowObserverTokens = [moveToken, resizeToken, becomeMainToken]
    }


    func addWindowObserver(center: NotificationCenter, name: NSNotification.Name, window: NSWindow, action: @escaping @MainActor () -> Void) -> NSObjectProtocol {
        center.addObserver(forName: name, object: window, queue: .main) { _ in
            Task { @MainActor in
                action()
            }
        }
    }


    func removeWindowObservers() {
        let center = NotificationCenter.default
        for token in windowObserverTokens {
            center.removeObserver(token)
        }
        windowObserverTokens.removeAll()
    }


    func scheduleFrameSave(for window: NSWindow) {
        frameSaveWorkItem?.cancel()
        let frame = window.frame
        let workItem = DispatchWorkItem {
            saveFrame(frame)
        }
        frameSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.frameAutosaveDelay, execute: workItem)
    }


    func saveFrame(_ frame: NSRect) {
        let storedFrame = StoredFrame(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.size.width,
            height: frame.size.height
        )
        guard let data = try? JSONEncoder().encode(storedFrame) else { return }
        UserDefaults.standard.set(data, forKey: WindowState.frameKey)
    }


    func loadStoredFrame() -> StoredFrame? {
        guard let data = UserDefaults.standard.data(forKey: WindowState.frameKey) else { return nil }
        return try? JSONDecoder().decode(StoredFrame.self, from: data)
    }
}
