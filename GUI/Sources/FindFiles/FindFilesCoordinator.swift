// FindFilesCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 11.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Find Files as a standalone NSWindow with persistent frame

import AppKit
import SwiftUI

// MARK: - Find Files Coordinator
/// Manages the Find Files window lifecycle.
/// The window is a standalone panel (not an overlay), remembers its size and position,
/// and defaults to a reasonable size that doesn't cover the main window.
@MainActor
@Observable
final class FindFilesCoordinator {

    static let shared = FindFilesCoordinator()

    // MARK: - State
    private(set) var isVisible = false
    private var findWindow: NSWindow?
    private let viewModel = FindFilesViewModel()

    private let frameAutosaveName = "MiMiNavigator.FindFilesWindow"
    private let defaultWidth: CGFloat = 680
    private let defaultHeight: CGFloat = 520

    private init() {}

    // MARK: - Toggle

    func toggle(searchPath: String, selectedFile: CustomFile? = nil) {
        if isVisible {
            close()
        } else {
            open(searchPath: searchPath, selectedFile: selectedFile)
        }
    }

    // MARK: - Open

    func open(searchPath: String, selectedFile: CustomFile? = nil) {
        viewModel.configure(searchPath: searchPath, selectedFile: selectedFile)

        if let existing = findWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            isVisible = true
            return
        }

        let contentView = FindFilesWindowContent(viewModel: viewModel)
            .frame(minWidth: 520, minHeight: 400)

        let hostingView = NSHostingView(rootView: contentView)

        let window = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "Find Files"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 400)
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.animationBehavior = .utilityWindow
        window.isMovableByWindowBackground = true
        // Follow main window: rise when app activates, stay visible when app is active
        window.hidesOnDeactivate = true
        window.level = .floating
        window.tabbingMode = .disallowed

        // Restore saved frame or compute default position
        if !window.setFrameUsingName(frameAutosaveName) {
            // No saved frame — position to the right of main window, not covering it
            let frame = computeDefaultFrame()
            window.setFrame(frame, display: true)
        }
        window.setFrameAutosaveName(frameAutosaveName)

        window.delegate = FindFilesWindowDelegate.shared
        window.makeKeyAndOrderFront(nil)

        findWindow = window
        isVisible = true
        log.info("[FindFiles] Window opened")
    }

    // MARK: - Close

    func close() {
        findWindow?.close()
        isVisible = false
        log.info("[FindFiles] Window closed")
    }

    // MARK: - Notify Closed (called by delegate)

    func windowDidClose() {
        isVisible = false
    }

    // MARK: - Default Frame Calculation

    /// Computes initial frame: right side of main window or centered if no main window
    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)

        if let mainWindow = NSApp.mainWindow {
            let mainFrame = mainWindow.frame
            let screenFrame = mainWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

            // Position to the right of main window
            var x = mainFrame.maxX + 12
            let y = mainFrame.midY - size.height / 2

            // If it goes off-screen right, try left side
            if x + size.width > screenFrame.maxX {
                x = mainFrame.minX - size.width - 12
            }
            // If still off-screen, overlap slightly at the right
            if x < screenFrame.minX {
                x = mainFrame.maxX - size.width * 0.3
            }

            let clampedY = max(screenFrame.minY, min(y, screenFrame.maxY - size.height))
            return NSRect(origin: NSPoint(x: x, y: clampedY), size: size)
        }

        // No main window — center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.midY - size.height / 2
            return NSRect(origin: NSPoint(x: x, y: y), size: size)
        }

        return NSRect(origin: .zero, size: size)
    }
}

// MARK: - Window Delegate
/// Handles window close notification to update coordinator state
private final class FindFilesWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = FindFilesWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            FindFilesCoordinator.shared.windowDidClose()
        }
    }
}
