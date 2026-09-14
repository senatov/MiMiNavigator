// FindFilesCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages Find Files as a standalone NSPanel with persistent frame.

import AppKit
import FileModelKit
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
    private var resultsWindow: NSPanel?
    var sheetWindow: NSWindow? {
        if let resultsWindow, resultsWindow.isKeyWindow { return resultsWindow }
        return findWindow
    }
    private var viewModel = FindFilesViewModel()
    /// Reference to AppState for "Show in Panel" feature
    var appState: AppState?

    private let frameAutosaveName = "MiMiNavigator.FindFilesWindow"
    private let defaultWidth: CGFloat = 940
    private let defaultHeight: CGFloat = 780

    private init() {}

    // MARK: - Toggle

    func toggle(searchPath: String, selectedFile: CustomFile? = nil, appState: AppState? = nil) {
        if let appState { self.appState = appState }
        open(searchPath: searchPath, selectedFile: selectedFile)
    }

    // MARK: - Open

    func open(searchPath: String, selectedFile: CustomFile? = nil) {
        viewModel.savePreferences()
        viewModel.cancelSearch()
        WindowReplacement.close(resultsWindow)
        resultsWindow = nil
        WindowReplacement.close(findWindow)
        findWindow = nil
        viewModel = FindFilesViewModel()
        viewModel.configure(searchPath: searchPath, selectedFile: selectedFile)
        log.debug(#function)
        let contentView = FindFilesWindowContent(viewModel: viewModel, appState: appState)
            .frame(minWidth: 680, minHeight: 580)
        let hostingView = NSHostingView(rootView: contentView)
        let window = FindFilesPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.onSelectAll = { [weak viewModel] in
            viewModel?.selectAllResults()
        }
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 680, height: 580)
        window.titlebarAppearsTransparent = false
        PanelTitleHelper.applyIconTitle(to: window, systemImage: "magnifyingglass", title: "Find Files")
        window.toolbarStyle = .unified
        window.animationBehavior = .utilityWindow
        window.isMovableByWindowBackground = false
        WindowPresentationPolicy.apply(.standalone, to: window)
        window.autorecalculatesKeyViewLoop = true

        // Restore saved frame or compute default position
        if !window.setFrameUsingName(frameAutosaveName) {
            // No saved frame — position to the right of main window, not covering it
            let frame = computeDefaultFrame()
            window.setFrame(frame, display: true)
        }
        window.setFrameAutosaveName(frameAutosaveName)
        window.delegate = FindFilesWindowDelegate.shared
        WindowPresentationPolicy.presentStandalone(window)
        window.recalculateKeyViewLoop()
        findWindow = window
        isVisible = true
        log.info("[FindFiles] Window opened")
    }

    // MARK: - Independent Results Window
    func showResultsWindow() {
        if let resultsWindow {
            WindowPresentationPolicy.presentStandalone(resultsWindow)
            return
        }
        let window = FindFilesPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: FindFilesResultsView(viewModel: viewModel, appState: appState))
        window.onSelectAll = { [weak viewModel] in viewModel?.selectAllResults() }
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 680, height: 260)
        window.title = "Find Files — Results"
        WindowPresentationPolicy.apply(.standalone, to: window)
        if !window.setFrameUsingName("MiMiNavigator.FindFilesResultsWindow") { window.center() }
        window.setFrameAutosaveName("MiMiNavigator.FindFilesResultsWindow")
        window.delegate = FindFilesWindowDelegate.shared
        resultsWindow = window
        WindowPresentationPolicy.presentStandalone(window)
    }

    // MARK: - Close

    func close() {
        findWindow?.makeFirstResponder(nil)
        viewModel.savePreferences()
        viewModel.cancelSearch()
        findWindow?.close()
        isVisible = false
        log.info("[FindFiles] Window closed")
    }

    // MARK: - Notify Closed (called by delegate)

    func windowDidClose(_ closedWindow: NSWindow) {
        if resultsWindow === closedWindow {
            closedWindow.contentView = nil
            closedWindow.delegate = nil
            resultsWindow = nil
            return
        }
        guard findWindow === closedWindow else { return }
        WindowReplacement.close(resultsWindow)
        resultsWindow = nil
        viewModel.savePreferences()
        closedWindow.contentView = nil
        closedWindow.delegate = nil
        findWindow = nil
        isVisible = false
    }

    // MARK: - Default Frame Calculation

    /// Computes initial frame: centered over main window
    private func computeDefaultFrame() -> NSRect {
        let size = NSSize(width: defaultWidth, height: defaultHeight)
        if let mainWindow = NSApp.mainWindow {
            let mf = mainWindow.frame
            let x = mf.midX - size.width / 2
            let y = mf.midY - size.height / 2
            return NSRect(origin: NSPoint(x: x, y: y), size: size)
        }
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            return NSRect(origin: NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2), size: size)
        }
        return NSRect(origin: .zero, size: size)
    }
}

// MARK: - Find Files Panel
@MainActor
private final class FindFilesPanel: NSPanel {
    var onSelectAll: (() -> Void)?

    // MARK: - Perform Key Equivalent
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.function, .numericPad])
        guard modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "a" else {
            return super.performKeyEquivalent(with: event)
        }
        if let responder = firstResponder, responder is NSTextView || responder is NSTextField {
            return super.performKeyEquivalent(with: event)
        }
        onSelectAll?()
        return true
    }
}

// MARK: - Window Delegate
/// Handles window close notification to update coordinator state
private final class FindFilesWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = FindFilesWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }
        Task { @MainActor in
            FindFilesCoordinator.shared.windowDidClose(closedWindow)
        }
    }
}
